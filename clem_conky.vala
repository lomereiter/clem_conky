/* to compile:
   valac --pkg gio-2.0 clem_conky.vala

   example of usage:
      clem_conky '#{artist} - #{title}; elapsed: #{elapsed}/#{time}'
 */

struct PlayerStatus {
    public int state;
    public int random;
    public int repeat_track;
    public int repeat_playlist;
}

[DBus (name = "org.freedesktop.MediaPlayer")]
interface Player : Object {
    public abstract HashTable<string, Variant> GetMetadata() throws IOError;
    public abstract int32 PositionGet() throws IOError;
    public abstract int32 VolumeGet() throws IOError;
    public abstract PlayerStatus GetStatus() throws IOError;
}

string seconds_to_str(int32 seconds) {
    int32 minutes = seconds / 60;
    seconds -= minutes * 60;
    StringBuilder sb = new StringBuilder();
    sb.printf("%d:%02d", minutes, seconds);
    return sb.str;
}

void main(string[] args) {
    if (args.length < 2) {
        return;
    }

    Player player = null;
    try {
        player = Bus.get_proxy_sync(BusType.SESSION, "org.mpris.clementine",
                                                     "/Player");
        PlayerStatus status = player.GetStatus();
        HashTable<string, Variant> track_info = player.GetMetadata();

        int32 ms_elapsed = player.PositionGet();
        int32 ms_totaltime = track_info.lookup("mtime").get_int32();

        Regex regex = new Regex("\\#\\{(.*?)\\}");
        stdout.printf("%s", regex.replace_eval(args[1], -1, 0, 0, 
          (match, result) => {
            string param = match.fetch(1).strip();
            try {
            if (param.has_prefix("cover")) {
                try {
                result.append("${image ");
                result.append(param.replace("cover",
                              Filename.from_uri(
                                   track_info.lookup("arturl").get_string())));
                result.append("}");
                } catch (ConvertError e) { stderr.printf(e.message); }
            } else 
            switch (param) {
                case "bar":
                case "progressbar":
                    result.append_printf("${execibar 1 echo %.1f}",
                        100.0 * ms_elapsed / ms_totaltime);
                    break;
                case "bitrate":
                    result.append_printf("%d",
                        track_info.lookup("audio-bitrate").get_int32());
                    break;
                case "elapsed":
                case "curtime":
                    result.append_printf(
                            seconds_to_str(ms_elapsed / 1000));
                    break;
                case "file":
                case "location":
                    result.append_printf(
                        track_info.lookup("location").get_string());
                    break;
                case "frequency":
                case "samplerate":
                    result.append_printf("%d",
                        track_info.lookup("audio-samplerate").get_int32());
                    break;
                case "length":
                case "time":
                case "totaltime":
                    result.append_printf(
                        seconds_to_str(ms_totaltime/ 1000));
                    break;
                case "percent":
                    result.append_printf("%2.0f", 
                        100.0 * ms_elapsed / ms_totaltime);
                    break;
                case "random":
                case "shuffle":
                    result.append_printf(status.random == 1 ? "On" : "Off");
                    break;
                case "repeat":
                case "repeat_track":
                    result.append_printf(status.repeat_track == 1 ? "On" : "Off");
                    break;
                case "repeat_playlist":
                    result.append_printf(status.repeat_playlist == 1 ? "On" : "Off");
                    break;
                case "status":
                    switch (status.state) {
                        case 0:
                            result.append("Playing");
                            break;
                        case 1:
                            result.append("Paused");
                            break;
                        case 2:
                            result.append("Stopped");
                            break;
                    }
                    break;
                case "track":
                case "tracknumber":
                case "playlist_position":
                    result.append_printf(
                        "%02d", track_info.lookup("tracknumber").get_int32());
                    break;
                case "volume":
                    result.append_printf(
                        "%02d", player.VolumeGet());
                    break;
                default: /* album, artist, title, genre, year */
                    Variant v = track_info.lookup(param);
                    if (v.get_type().equal(VariantType.STRING)) {
                        result.append(v.get_string());
                    } else {
                        result.append(v.print(false));
                    }
                    break;
            }
            } catch (IOError e) {
                stderr.printf(e.message);
            }
            return false;
        }));

    } catch (Error e) {
        stderr.printf(e.message);
    }
}
