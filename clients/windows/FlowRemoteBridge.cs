using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Threading;
using System.Web.Script.Serialization;
class FlowRemoteBridge
{
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]static extern int sqlite3_open_v2(byte[] n,out IntPtr db,int flags,IntPtr vfs);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]static extern int sqlite3_close(IntPtr db);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]delegate int Callback(IntPtr p,int n,IntPtr vals,IntPtr cols);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]static extern int sqlite3_exec(IntPtr db,byte[] sql,Callback c,IntPtr p,out IntPtr err);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]static extern void sqlite3_free(IntPtr p);
    [DllImport("user32.dll")]static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr w,out uint pid);
    static string Dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"FlowRemoteBridge");
    static string SshHost, ClientId, WslDistribution, WslUser;
    static JavaScriptSerializer Json=new JavaScriptSerializer();
    static string Str(IntPtr p)
    {
        if(p==IntPtr.Zero)return "";
        int n=0;
        while(Marshal.ReadByte(p,n)!=0)n++;
        byte[] b=new byte[n];
        Marshal.Copy(p,b,0,n);
        return Encoding.UTF8.GetString(b);
    }
    static List<string[]> Query(string sql)
    {
        IntPtr db,err;
        string path=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"Wispr Flow","flow.sqlite");
        int rc=sqlite3_open_v2(Encoding.UTF8.GetBytes(path+"\0"),out db,1,IntPtr.Zero);
        if(rc!=0)
        {
            if(db!=IntPtr.Zero)sqlite3_close(db);
            throw new Exception("database-open-"+rc);
        }
        var rows=new List<string[]>();
        Callback cb=(p,n,v,c)=>
        {
            var row=new string[n];
            for(int i=0;i<n;i++)row[i]=Str(Marshal.ReadIntPtr(v,i*IntPtr.Size));
            rows.Add(row);
            return 0;
        };
        try
        {
            rc=sqlite3_exec(db,Encoding.UTF8.GetBytes(sql+"\0"),cb,IntPtr.Zero,out err);
            if(err!=IntPtr.Zero)sqlite3_free(err);
            if(rc!=0)throw new Exception("database-query-"+rc);
            return rows;
        }
        finally
        {
            sqlite3_close(db);
        }
    }
    static bool ConnectedLog(string data)
    {
        string last=data.Split('\n').Select(x=>x.Trim()).LastOrDefault(x=>x.Contains("Client Status received:")||x.Contains("===== Parsec:"));
        return last!=null&&last.EndsWith("Client Status received: 0");
    }
    static bool Connected()
    {
        try
        {
            string path=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"Parsec","log.txt");
            string data;
            using(var f=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
            {
                f.Seek(Math.Max(0,f.Length-131072),SeekOrigin.Begin);
                using(var r=new StreamReader(f))
                {
                    data=r.ReadToEnd();
                }
            }
            return ConnectedLog(data);
        }
        catch
        {
            return false;
        }
    }
    static string PendingAction(double ageSeconds, bool foreground)
    {
        if(ageSeconds>1500)return "expire";
        return foreground ? "ready" : "pause";
    }
    static bool Foreground()
    {
        if(!Connected())return false;
        uint pid;
        GetWindowThreadProcessId(GetForegroundWindow(),out pid);
        try
        {
            return Process.GetProcessById((int)pid).ProcessName.Equals("parsecd",StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }
    static void Log(string s)
    {
        try
        {
            Directory.CreateDirectory(Dir);
            string p=Path.Combine(Dir,"watcher.log");
            if(File.Exists(p)&&new FileInfo(p).Length>131072)
            {
                string old=p+".1";
                if(File.Exists(old))File.Delete(old);
                File.Move(p,old);
            }
            File.AppendAllText(p,DateTime.Now.ToString("s")+" "+s+Environment.NewLine);
        }
        catch
        {
        }
    }
    static Dictionary<string,object> Request(Dictionary<string,object> r)
    {
        r["client"]=ClientId;
        var psi=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "wsl.exe"),"-d "+WslDistribution+" -u "+WslUser+" -- ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5 "+SshHost+" .local/bin/flow-remote-submit");
        psi.UseShellExecute=false;
        psi.CreateNoWindow=true;
        psi.RedirectStandardInput=true;
        psi.RedirectStandardOutput=true;
        psi.RedirectStandardError=true;
        psi.StandardOutputEncoding=Encoding.UTF8;
        using(var p=Process.Start(psi))
        {
            var o=p.StandardOutput.ReadToEndAsync();
            var e=p.StandardError.ReadToEndAsync();
            byte[] bytes=Encoding.UTF8.GetBytes(Json.Serialize(r)+"\n");
            p.StandardInput.BaseStream.Write(bytes,0,bytes.Length);
            p.StandardInput.BaseStream.Flush();
            p.StandardInput.Close();
            if(!p.WaitForExit(12000))
            {
                p.Kill();
                return new Dictionary<string,object>
                {
                    { "status", "transport-timeout" }
                };
            }
            if(p.ExitCode!=0)return new Dictionary<string,object>
            {
                { "status", "transport-failed" }
            };
            return Json.Deserialize<Dictionary<string,object>>(o.Result);
        }
    }
    class Pending
    {
        public string Id,Token,Body;
        public DateTime Born,Stable;
    }
    [STAThread]
    static void Main(string[] args)
    {
        try { Run(args); }
        catch (Exception error)
        {
            Log("Startup failed: " + error.GetType().Name);
            Console.Error.WriteLine("Startup failed; check configuration and watcher.log.");
            Environment.ExitCode = 1;
        }
    }
    static void Run(string[] args)
    {
        bool created;
        using(var mutex=new Mutex(true,"Local\\FlowRemoteBridge",out created))
        {
            if(!created)return;
            var config=Json.Deserialize<Dictionary<string,string>>(File.ReadAllText(Path.Combine(Dir,"config.json")));
            ClientId=config["client_id"];
            SshHost=config["ssh_host"];
            WslDistribution=config["wsl_distribution"];
            WslUser=config["wsl_user"];
            foreach(var value in new[] { ClientId, SshHost, WslDistribution, WslUser })
                if(!System.Text.RegularExpressions.Regex.IsMatch(value,@"^[A-Za-z0-9_][A-Za-z0-9_.@-]{0,127}$"))throw new Exception("Invalid configuration identifier");
            if(!System.Text.RegularExpressions.Regex.IsMatch(ClientId,@"^[A-Za-z0-9_-]{1,64}$"))throw new Exception("Invalid client_id");
            if(args.Contains("--health"))
            {
                Console.WriteLine(Json.Serialize(Request(new Dictionary<string,object>
                {
                    { "op", "health" }
                }
                )));
                return;
            }
            long watermark;
            while(true)
            {
                try
                {
                    watermark=long.Parse(Query("select coalesce(max(rowid),0) from History")[0][0]);
                    break;
                }
                catch
                {
                    Log("Waiting for Flow history database");
                    Thread.Sleep(5000);
                }
            }
            var pending=new Dictionary<long,Pending>();
            Log("Started; existing history excluded");
            while(true)
            {
                try
                {
                    string extra=pending.Count>0?" OR rowid IN ("+String.Join(",",pending.Keys)+")":"";
                    var rows=Query("select rowid,transcriptEntityId,status,app,CASE WHEN app='parsecd' THEN coalesce(nullif(pastedText,''),formattedText,'') ELSE '' END from History where rowid>"+watermark+extra+" order by rowid limit 64");
                    foreach(var r in rows)
                    {
                        long n=long.Parse(r[0]);
                        bool fresh=n>watermark;
                        watermark=Math.Max(watermark,n);
                        if(fresh)
                        {
                            if(r[3]!=""&&r[3]!="parsecd")continue;
                            if(pending.Count>=64||!Foreground())continue;
                            var arm=Request(new Dictionary<string,object>
                            {
                                { "op", "arm" }
                                ,
                                { "id", r[1] }
                            }
                            );
                            if((string)arm["status"]!="armed")
                            {
                                Log("Arm skipped: "+arm["status"]);
                                continue;
                            }
                            pending[n]=new Pending
                            {
                                Id=r[1],Token=(string)arm["token"],Born=DateTime.UtcNow
                            };
                        }
                        Pending item;
                        if(!pending.TryGetValue(n,out item))continue;
                        string action=PendingAction((DateTime.UtcNow-item.Born).TotalSeconds,Foreground());
                        if(action=="expire")
                        {
                            pending.Remove(n);
                            Log("Cancelled: expired");
                            continue;
                        }
                        if(r[3]!=""&&r[3]!="parsecd")
                        {
                            pending.Remove(n);
                            continue;
                        }
                        if(action=="pause")continue;
                        if(r[2]=="formatted"&&r[4]!="")
                        {
                            if(item.Body!=r[4])
                            {
                                item.Body=r[4];
                                item.Stable=DateTime.UtcNow;
                                continue;
                            }
                            if((DateTime.UtcNow-item.Stable).TotalSeconds<0.7)continue;
                            if(Foreground())
                            {
                                pending.Remove(n); // Never replay an uncertain delivery.
                                var reply=Request(new Dictionary<string,object>
                                {
                                    { "op", "paste" }
                                    ,
                                    { "id", item.Id }
                                    ,
                                    { "token", item.Token }
                                    ,
                                    { "text", item.Body }
                                }
                                );
                                Log("Delivery: "+reply["status"]+" age_s="+(int)(DateTime.UtcNow-item.Born).TotalSeconds+" bytes="+Encoding.UTF8.GetByteCount(item.Body));
                            }
                        }
                    }
                }
                catch(Exception e)
                {
                    pending.Clear();
                    Log("Paused: "+e.GetType().Name);
                    Thread.Sleep(2000);
                }
                Thread.Sleep(300);
            }
        }
    }
}
