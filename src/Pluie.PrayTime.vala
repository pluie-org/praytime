using GLib;
using Gst;

class Pluie.PrayTime : GLib.Object
{
    public  const string   HEADER    = """         ____                  _______              
        / __ \_________ ___  _/_  __(_____ ___  ___ 
       / /_/ / ___/ __ `/ / / // / / / __ `__ \/ _ \
      / ____/ /  / /_/ / /_/ // / / / / / / / /  __/
     /_/   /_/   \__,_/\__, //_/ /_/_/ /_/ /_/\___/ 
       by a-sansara   /____/   gnu gpl v3

""";
    public  const string   COLOR1    = "\033[1;38;5;36m";
    public  const string   COLOR2    = "\033[1;38;5;97m";
    public  const string   COLOR3    = "\033[1;38;5;255m";
    public  const string   COLOR4    = "\033[1;38;5;157m";
    public  const string   COLOR5    = "\033[1;38;5;67m";
    public  const string   COLOR6    = "\033[1;38;5;193m";
    public  const string   COLOR_OFF = "\033[m";

    private const bool     DEBUG     = false;
    private const string   SEP       = "__________________________________________________________\n";
    private const string[] PRAYLIST  = { "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha" };
    private const string   protocol  = "http";
    private const string   hostname  = "api.aladhan.com";
    private const string   uri       = "timingsByCity?";

    private string         path;
    private string         version;
    private string         bin;
    private GLib.KeyFile   kf;
    private GLib.MainLoop  loop;
    private Gst.Element    playbin;


    public PrayTime (string path, string bin, string version)
    {
        this.path    = path;
        this.version = version;
        this.bin     = bin;
        this.kf      = this.load_config ("praytime.ini");
    }


    public void play_adhan (string pray)
    {
        if (pray in PrayTime.PRAYLIST) {
            double volume = this.get_volume (pray.down ());
            string mp3    = this.get_mp3 (pray.down ());
            stdout.printf (
                "%s%s%s %s %s time%s \n",
                PrayTime.COLOR1,
                PrayTime.SEP,
                PrayTime.HEADER,
                PrayTime.COLOR6,
                pray,
                PrayTime.COLOR_OFF
            );
            this.play (mp3, volume);
            stdout.printf (
                "%s%s%s\n",
                PrayTime.COLOR1,
                PrayTime.SEP,
                PrayTime.COLOR_OFF
            );
        }
        else {
            this.on_error(@"invalid pray parameter '$pray'");
        }
    }


    public void infos()
    {
        KeyFile k = this.load_config ("praytime.daily.ini", true);
        var date  = new GLib.DateTime.now_local ();
        stdout.printf (
            "%s%s%s%s %s %s %s  %s %s %s\n%s%s%s\n", 
            PrayTime.COLOR1, 
            PrayTime.SEP,
            PrayTime.HEADER, 
            PrayTime.COLOR6,
            this.get_config ("city"), 
            this.get_config ("country"),
            PrayTime.COLOR3,
            date.format ("%z %A %d %B %Y"),
            PrayTime.COLOR4,
            date.format ("%T"),
            PrayTime.COLOR1,
            PrayTime.SEP,
            PrayTime.COLOR_OFF
        );
        foreach (string pray in PrayTime.PRAYLIST) {
            try {
                stdout.printf (
                    " %s%10s%s : %s%s%s\n",
                    PrayTime.COLOR1,
                    pray,
                    PrayTime.COLOR3,
                    PrayTime.COLOR4,
                    k.get_string ("Praytime", pray.down ()),
                    PrayTime.COLOR_OFF
                );
            }
            catch (GLib.KeyFileError e) {
                this.on_error (e.message);
            }
        }
    }


    public void init_cron ()
    {
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
            this.infos ();
        }
        catch (Error e) {
            this.on_error (e.message);
        }
    }


    private void on_error (string msg)
    {
        if (PrayTime.DEBUG) {
            message (msg);
        }
        stderr.printf (" Error : %s\n", msg);
    }


    private string get_config_file (string basename, bool tmp)
    {
        return Path.build_filename (!tmp ? this.path : Environment.get_tmp_dir (), basename);
    }


    private KeyFile load_config (string basename, bool tmp = false)
    {
        KeyFile f = new KeyFile ();
        f.set_list_separator (',');
        try {
            f.load_from_file (this.get_config_file (basename, tmp), KeyFileFlags.NONE);
        }
        catch (KeyFileError e) {
            this.on_error (e.message);
        }
        catch (FileError e) {
            this.on_error (e.message);
        }
        return f;
    }


    private string get_mp3 (string key = "default")
    {
        string mp3 = this.get_config (key, "Adhan");
        if (mp3 == "" && key != "default") {
            mp3 = this.get_config ("default", "Adhan");
        }
        return mp3;
    }


    private double get_volume (string key = "default")
    {
        string volume = this.get_config (key, "Volumes");
        if (volume == "" && key != "default") {
            volume = this.get_config ("default", "Volumes");
        }
        return double.parse (volume);
    }


    private string get_config (string key, string group = "Params")
    {
        string v = "";
        try {
            v = this.kf.get_string (group, key);
        }
        catch (GLib.KeyFileError e) {
            this.on_error (e.message);
        }
        return v;
    }


    private int spawn_cmd (string cmd, out string response)
    {
        int    status;
        string std_error;
        try {
            Process.spawn_command_line_sync (cmd, out response, out std_error, out status);
        } catch (SpawnError e) {
            stderr.printf ("%s\n", e.message);
        }
        return status;
    }


    private string get_timings ()
    {
        string url  = "%s://%s/%scity=%s&country=%s&method=%s&latitudeAdjustmentMethod=%s".printf(
            PrayTime.protocol, 
            PrayTime.hostname, 
            PrayTime.uri, 
            this.get_config ("city"),
            this.get_config ("country"),
            this.get_config ("method"),
            this.get_config ("latitudeAdjustmentMethod")
        );
        var f        = File.new_for_uri (url);
        var response = "";
        try {
            FileInputStream fs = f.read ();
            var dis  = new DataInputStream (fs);
            string line;
            while ((line = dis.read_line (null)) != null) {
                response += line + "\n";
            }
        }
        catch (GLib.Error e) {
            this.on_error (e.message);
            response = this.get_alt_timings (url);
        }
        return response;
    }


    private string get_alt_timings (string url)
    {
        stdout.printf(" trying alternate method to get timings\n");
        string response;
        this.spawn_cmd ("curl %s".printf (url), out response);
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
            stdout.printf ("Error %s\n", e.message);
        }
        return data;
    }


    private void set_cron (GLib.DateTime date)
    {
        try {
            KeyFile  k         = this.load_config ("praytime.daily.ini", true);
            string?  user      = Environment.get_variable ("SUDO_USER");
            if (user == null) {
                user      = Environment.get_variable ("USER");
            }
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
                    stdout.printf ("\n updating crontab %s : %s\n", user, status == 0 ? "ok" : "ko");
                }
            }
        }
        catch (GLib.KeyFileError e) {
            this.on_error (e.message);
        }
        catch(GLib.FileError e) {
            this.on_error (e.message);
        }
    }


    private void write_timings (Json.Object results, GLib.DateTime date)
    {
        string data = "[Praytime]\n# %s\n%-10s = %s\n".printf (date.format ("%c"), "timestamp", date.to_unix ().to_string ());
        foreach (string pray in PrayTime.PRAYLIST) {
            data += "%-10s = %s\n".printf (pray.down(), results.get_string_member (pray));
        }
        try {
            FileUtils.set_contents (this.get_config_file ("praytime.daily.ini", true), data);
        }
        catch (GLib.FileError e) {
            stderr.printf ("%s\n", e.message);
        }
    }


    private void play (string f, double volume = 1.0, string[]? params = null)
    {
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
            this.on_error (e.message);
        }
        catch (Error e) {
            this.on_error (e.message);
        }
    }


    private bool bus_callback (Gst.Bus bus, Gst.Message message)
    {
        switch (message.type) {

            case MessageType.ERROR:
                GLib.Error err;
                string debug;
                message.parse_error (out err, out debug);
                stdout.printf ("Error: %s\n", err.message);
                loop.quit ();
                break;

            case MessageType.EOS:
                stdout.printf ("end of stream\n");
                this.playbin.set_state (State.NULL);
                loop.quit ();
                break;

            default:
                break;
        }
        return true;
    }

}
