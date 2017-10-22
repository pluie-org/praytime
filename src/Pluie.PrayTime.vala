using GLib;
using Gst;

class Pluie.PrayTime : GLib.Object
{
    const   bool          DEBUG    = false;
    const   string        SEP      = "----------------------------------------------------------";
    const   string[]      PRAYLIST = { "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha" };
    const   string        protocol = "http";
    const   string        hostname = "api.aladhan.com";
    const   string        uri      = "timingsByCity?";

    private string        path;
    private string        version;
    private string        bin;
    private GLib.KeyFile  kf;
    private GLib.MainLoop loop;
    private Gst.Element   playbin;


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
            this.play (mp3, volume);
        }
        else {
            this.on_error(@"invalid pray parameter '$pray'");
        }
    }


    public void infos()
    {
        KeyFile k = this.load_config ("praytime.daily.ini");
        var date  = new GLib.DateTime.now_local ();
        stdout.printf (
            "%s\n %s %s - %s\n%s\n", 
            PrayTime.SEP, 
            this.get_config ("city"), 
            this.get_config ("country"), 
            date.format ("%z %A %d %B %Y %T"), 
            PrayTime.SEP
        );
        foreach (string pray in PrayTime.PRAYLIST) {
            try {
                stdout.printf (" %10s : %s\n", pray, k.get_string ("Praytime", pray.down ()));
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


    private string get_config_file (string basename)
    {
        return Path.build_filename (this.path, basename);
    }


    private KeyFile load_config (string basename)
    {
        KeyFile f = new KeyFile ();
        f.set_list_separator (',');
        try {
            f.load_from_file (this.get_config_file (basename), KeyFileFlags.NONE);
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
            // root user experience problem with that
            // don't know why, use curl as alternative
            // in get_alt_timings
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
        string response = "";
        string std_error;
        int    status;
        try {
            Process.spawn_command_line_sync (
                "curl "+url, 
                out response,
                out std_error,
                out status
            );
        } catch (SpawnError e) {
            stderr.printf ("%s\n", e.message);
        }
        return response;
    }

    private void set_cron (GLib.DateTime date)
    {
        try {
            string   bin       = "root "+Path.build_filename(this.bin, "praytime");
            string   cron_path = this.get_config ("path", "Cron");
            string[] update    = this.get_config ("time", "Cron").split (":", 2);
            string   content   = "# %s\n%d %d * * * %s %s\n".printf (date.format ("%c"), int.parse (update[1]), int.parse(update[0]) , bin, "cron");
            KeyFile k = this.load_config ("praytime.daily.ini");
            foreach (string pray in PrayTime.PRAYLIST) {
                string[] time = k.get_string ("Praytime", pray.down ()).split (":", 2);
                content += "%s %s * * * %s %s %s\n".printf (time[1], time[0] , bin, "play", pray); 
            }
            bool done = FileUtils.set_contents (cron_path, content);
            stdout.printf ("\n updating %s : %s\n", cron_path, done ? "ok" : "ko");
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
            FileUtils.set_contents (this.get_config_file ("praytime.daily.ini"), data);
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
