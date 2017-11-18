using GLib;
using Gst;

class Pluie.PrayTime : GLib.Object
{

    private const string[] PRAYLIST  = { "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha" };
    private const string   protocol  = "http";
    private const string   hostname  = "api.aladhan.com";
    private const string   uri       = "timingsByCity?";
    
    private Sys.Cmd        cmd;
    private string         path;
    public  string         version;
    private string         bin;
    private GLib.KeyFile   kf;
    private GLib.MainLoop  loop;
    private Gst.Element    playbin;    
    

    public PrayTime (string path, string bin, string version)
    {
        Dbg.in (Log.METHOD, "path:'%s':bin:'%s':version:'%s'".printf (path, bin, version), Log.LINE, Log.FILE);
        this.path    = path;
        this.version = version;
        this.bin     = bin;
        this.kf      = this.load_config ("praytime.ini");
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
    }


    public int play_adhan (string pray)
    {
        Dbg.in (Log.METHOD, "pray:'%s'".printf (pray), Log.LINE, Log.FILE);
        var done = 0;
        if (pray in PrayTime.PRAYLIST) {
            double volume = this.get_volume (pray.down ());
            string mp3    = this.get_mp3 (pray.down ());
            of.action ("Playing Adhan", "%s time".printf (pray));
            this.play (mp3, volume);
        }
        else {
            of.error (@"invalid pray parameter '$pray'");
            done = 1;
        }
        Dbg.out (Log.METHOD, "done ? %d".printf (done), Log.LINE, Log.FILE);
        return done;
    }


    public void infos (bool bypass_title = false)
    {
        Dbg.in (Log.METHOD, null, Log.LINE, Log.FILE);
        bool done = true;
        var date  = new GLib.DateTime.now_local ();
        KeyFile k = this.load_config ("praytime.daily.ini", true);
        if (!bypass_title) {
            of.title ("PrayTime", this.version, "a-sansara");
        }
        of.action (
            "Retriew timings for", 
            "%s %s\n".printf (this.get_config ("city"), this.get_config ("country"))
        );
        of.echo (date.format ("%z %A %d %B %Y"), false);
        of.echo (date.format ("%T"), true, false, ECHO.OPTION_SEP);
        of.echo ();
        int t = int.parse(date.format ("%H%M"));
        var s = "";
        var p = "";
        foreach (string pray in PrayTime.PRAYLIST) {
            try {
                p = k.get_string ("Praytime", pray.down ());
                s = (int.parse(p.substring (0, 2) + p.substring (3, 2))) > t ? "*" : " ";
                of.keyval(pray, "%s %s".printf( p, of.c (ECHO.MICROTIME).s (s)));
            }
            catch (GLib.KeyFileError e) {
                Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
                done = false;
            }
        }
        of.state (done);
        Dbg.out (Log.METHOD, "done:%d".printf ((int)done), Log.LINE, Log.FILE);
    }


    public void init_cron ()
    {
        Dbg.in (Log.METHOD, null, Log.LINE, Log.FILE);
        try {
            var parser  = new Json.Parser ();
            parser.load_from_data (this.get_timings ());
            var node      = parser.get_root ().get_object ().get_object_member ("data");
            var timestamp = node.get_object_member ("date").get_string_member ("timestamp");
            var time      = new GLib.DateTime.from_unix_utc (int.parse (timestamp));
            time          = time.to_timezone (new GLib.TimeZone.local ());
            var results   = node.get_object_member ("timings");
            this.write_timings (results, time);
            this.set_cron (time);
            this.infos (true);
        }
        catch (Error e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
    }


    private string get_config_file (string basename, bool tmp)
    {
        return Path.build_filename (!tmp ? this.path : Environment.get_tmp_dir (), basename);
    }


    private KeyFile load_config (string basename, bool tmp = false)
    {
        Dbg.in (Log.METHOD, null, Log.LINE, Log.FILE);
        KeyFile f = new KeyFile ();
        f.set_list_separator (',');
        try {
            f.load_from_file (this.get_config_file (basename, tmp), KeyFileFlags.NONE);
        }
        catch (KeyFileError e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        catch (FileError e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return f;
    }


    private string get_mp3 (string key = "default")
    {
        Dbg.in (Log.METHOD, "key:'%s'".printf (key), Log.LINE, Log.FILE);
        string mp3 = this.get_config (key, "Adhan");
        if (mp3 == "" && key != "default") {
            mp3 = this.get_config ("default", "Adhan");
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return mp3;
    }


    private double get_volume (string key = "default")
    {
        Dbg.in (Log.METHOD, "key:'%s'".printf (key), Log.LINE, Log.FILE);
        string volume = this.get_config (key, "Volumes");
        if (volume == "" && key != "default") {
            volume = this.get_config ("default", "Volumes");
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return double.parse (volume);
    }


    private string get_config (string key, string group = "Params")
    {
        Dbg.in (Log.METHOD, "key:'%s':group:'%s'".printf (key, group), Log.LINE, Log.FILE);
        string v = "";
        try {
            v = this.kf.get_string (group, key);
        }
        catch (GLib.KeyFileError e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return v;
    }


    private int spawn_cmd (string cmd, out string response)
    {
        Dbg.in (Log.METHOD, "cmd:'%s'".printf (cmd), Log.LINE, Log.FILE);
        if (this.cmd == null) this.cmd = new Sys.Cmd();
        this.cmd.run (false, cmd);
        response = this.cmd.output;
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return this.cmd.status;
    }


    private string get_timings ()
    {
        Dbg.in (Log.METHOD, null, Log.LINE, Log.FILE);
        of.action ("Loading timings");
        string url  = "%s://%s/%scity=%s&country=%s&method=%s&latitudeAdjustmentMethod=%s".printf(
            PrayTime.protocol, 
            PrayTime.hostname, 
            PrayTime.uri, 
            this.get_config ("city"),
            this.get_config ("country"),
            this.get_config ("method"),
            this.get_config ("latitudeAdjustmentMethod")
        );
        of.echo (url, true, false, ECHO.OPTION_SEP);
        var f        = File.new_for_uri (url);
        var response = "";
        try {
            FileInputStream fs = f.read ();
            var dis  = new DataInputStream (fs);
            string line;
            while ((line = dis.read_line (null)) != null) {
                response += line + "\n";
            }
            of.state (true);
        }
        catch (GLib.Error e) {
            of.state (false);
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
            response = this.get_alt_timings (url);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return response;
    }


    private string get_alt_timings (string url)
    {
        Dbg.in (Log.METHOD, "url:'%s'".printf (url), Log.LINE, Log.FILE);
        of.action ("Trying alternate method to load timings");
        string response;
        var status = this.spawn_cmd ("curl %s".printf (url), out response);
        of.state (status == 0);
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return response;
    }


    private int get_user_crontab_content (string user, out string response)
    {
        return this.spawn_cmd ("crontab -l -u %s".printf (user), out response);
    }


    private int install_user_crontab (string user, string path)
    {        
        string response;
        return this.spawn_cmd ("crontab %s -u %s".printf (path, user), out response);
    }


    private string? get_user_crontab (ref string user, ref string content)
    {
        Dbg.in (Log.METHOD, "user:'%s'".printf (user), Log.LINE, Log.FILE);
        string data = "";
        string udata;
        try {
            if (this.get_user_crontab_content (user, out udata) == 0) {
                var regex = new Regex (Path.build_filename (this.bin, "praytime").escape (null));
                foreach (string line in udata.split ("\n")) {
                    if (!regex.match (line) && line != "") {
                        data += line + "\n";
                    }
                }
                data += "\n" + content + "\n";
            }
        }
        catch (RegexError e) {
            data = null;
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return data;
    }


    private string get_user ()
    {
        Dbg.in (Log.METHOD, null, Log.LINE, Log.FILE);
        string? user = Environment.get_variable ("SUDO_USER");
        if (user == null) {
            user = Environment.get_variable ("USER");
        }
        if (user == null) {
            user = Environment.get_variable ("LOGNAME");
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
        return user;
    }


    private void set_cron (GLib.DateTime date)
    {
        Dbg.in (Log.METHOD, "date:'%s'".printf (date.format ("%F %Hh%Mm%S")), Log.LINE, Log.FILE);
        try {
            string   user      = this.get_user();
            of.action ("Setting crontab for user", user);
            KeyFile  k         = this.load_config ("praytime.daily.ini", true);
            string[] update    = this.get_config ("time", "Cron").split (":", 2);            
            string[] time      = null;
            string   bin       = Path.build_filename (this.bin, "praytime");
            string   cron_path = Path.build_filename (Environment.get_tmp_dir (), "praytime.crontab");
            string   content   = "# > autogenerated by %s %s\n".printf (bin, date.format ("%c")) + 
                                 "%02d %02d * * * %s cron\n".printf (int.parse (update[1]), int.parse (update[0]) , bin);
            foreach (string pray in PrayTime.PRAYLIST) {
                time     = k.get_string ("Praytime", pray.down ()).split (":", 2);
                content += "%s %s * * * sh -c \"DISPLAY=:0 %s play %s\"\n".printf (time[1], time[0] , bin, pray);
            }
            content  += "# < autogenerated by %s\n".printf(bin);            
            content   = this.get_user_crontab (ref user, ref content);
            if (content != null) {
                if (FileUtils.set_contents (cron_path, content)) {
                    int status = this.install_user_crontab (user, cron_path);
                    of.state (status == 0);
                }
            }
        }
        catch (GLib.KeyFileError e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        catch(GLib.FileError e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
    }


    private void write_timings (Json.Object results, GLib.DateTime date)
    {
        Dbg.in (Log.METHOD, "results:...:date:'%s'".printf (date.format ("%F %Hh%Mm%S")), Log.LINE, Log.FILE);
        of.action ("Saving timings");
        string data = "[Praytime]\n# %s\n%-10s = %s\n".printf (date.format ("%c"), "timestamp", date.to_unix ().to_string ());
        foreach (string pray in PrayTime.PRAYLIST) {
            data += "%-10s = %s\n".printf (pray.down(), results.get_string_member (pray));
        }
        try {
            var done = FileUtils.set_contents (this.get_config_file ("praytime.daily.ini", true), data);
            of.state (done);
        }
        catch (GLib.FileError e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
    }


    private void play (string f, double volume = 1.0, string[]? params = null)
    {
        Dbg.in (Log.METHOD, "f:'%s':volume:%0.1f".printf (f, volume), Log.LINE, Log.FILE);
        try {
            Gst.init (ref params);
            this.loop = new GLib.MainLoop ();        
            var pipeline = Gst.parse_launch ("playbin uri=\"file://%s\"".printf (f));
            this.playbin = pipeline;
            this.playbin.set_state (State.PLAYING);
            this.playbin.set ("volume", volume);
            this.playbin.get_bus ().add_watch (0, this.bus_callback);
            this.loop.run ();
        }
        catch (FileError e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        catch (Error e) {
            Dbg.error (e.message, Log.METHOD, Log.LINE, Log.FILE);
        }
        Dbg.out (Log.METHOD, null, Log.LINE, Log.FILE);
    }


    private bool bus_callback (Gst.Bus bus, Gst.Message message)
    {
        switch (message.type) {

            case MessageType.ERROR:
                GLib.Error err;
                string debug;
                message.parse_error (out err, out debug);
                of.error (err.message);
                loop.quit ();
                break;

            case MessageType.EOS:
                of.echo ("end of stream");
                this.playbin.set_state (State.NULL);
                loop.quit ();
                break;

            default:
                break;
        }
        return true;
    }

    public void usage ()
    {
        of.echo ("\nUsage :", true, true, ECHO.VAL);
        of.usage_command("praytime", "cron"  , ""            , "%s\n%s\n%s".printf (
            "# update user crontab",
            "# before installing please check config file ",
            "# %s/praytime.ini".printf (this.path)
        ));
        of.usage_command("praytime", "version", ""           , "# display program version");
        of.usage_command("praytime", "play"   , "PRAYER_NAME", "# play adhan (Fajr, Dhuhr, Asr, Maghrib, Isha)");
        of.usage_command("praytime", ""       , ""           , "# display prayer timings");
    }

}
