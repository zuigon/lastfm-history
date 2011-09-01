t = Time.now
# require "rubygems"
require "net/http"
require "./xmlsimple"
require "./active_support/time"
t = Time.now - t

class String
  def is_num?
    true if Float(self) rescue false
  end
end

@user = "bkrsta"
@apikey = "b25b959554ed76058ac220b7b2e0a026"
MAX_TS = 9000000000
@got = 0
@limit = 0
@st = 0

@debug = ARGV.last == "-v"

def debug(text)
  puts "DEBUG: #{text}" if @debug
end

def ts
  @st = Time.now
end

def st(txt)
  debug "#{txt} in #{sprintf "%.2f", (Time.now-@st)}s" if @debug
end

debug "libs loaded in #{sprintf "%.2f", t}s"

def genurl(opts={})
  rooturl = "http://ws.audioscrobbler.com/2.0/"
  d = {
    :api_key => @apikey,
    :user => 'bkrsta',
    :method => 'user.getrecenttracks',
    :limit => '5'
  }
  d.merge! opts
  args = d.keys.map{|k| "#{k}=#{d[k]}"}.join("&")
  url = "#{rooturl}?#{args}"
end

def get(opts={})
  url = genurl opts
  debug "get() url: #{url}"
  ts
  xml = Net::HTTP.get_response(URI.parse(url)).body
  st "HTTP reqest"
  ts
  data = XmlSimple.xml_in(xml)
  st "XML parse"
  debug "get() data:"
  puts data.inspect if @debug
  if data['status'] != 'ok'
    puts "ERR: Request returned status '#{data['status'] || '??'}'"
    puts "MSG: #{data['error'].first['content'] rescue '??'} (code: #{data['error'].first['code'] rescue '??'})"
    return false
  end
  data
end

def tracks_to_s(tracks)
  tracks.
  sort{|a,b| a[:ts]<=>b[:ts]}.
    collect{|t|
      "#{t[:ts] == MAX_TS ? "Now playing" : Time.at(t[:ts]).strftime("%d %h %Y %H:%M:%I")} - #{t[:artist]} - #{t[:name]}" if
      t["nowplaying"] != "true"
    }.join "\n"
end

def to_track(d)
  {
    :name => d["name"][0],
    :artist => d["artist"][0]["content"],
    :ts => (d["date"][0]["uts"].to_i rescue MAX_TS),
    :current => (d[""])
  }
end

def get_tracks(opts={})
  page = 0; pages = nil; data = nil; tracks = []
  while @got <= @limit && (data.nil? || data["recenttracks"].first["page"] != pages)
    page += 1
    debug "page: #{page}"
    data = get(opts.merge :page => page)
    if data == false
      return tracks
    end
    pages = data["recenttracks"].first["totalPages"]
    if data["recenttracks"].first["track"].nil?
      return
    else
      data["recenttracks"].first["track"].each{|t|
        tracks << to_track(t)
        @got+=1
        debug "Got: #{tracks_to_s [to_track(t)]}"
      }
    end
  end
  # debug "tracks: #{tracks.inspect}"
  return tracks
end

if __FILE__ == $0

  if ARGV[0]
    if ARGV[0] == "before" && ARGV[1]
      debug "before"
      t = ARGV[1]
      if ! t =~ /^\d+[mhdMY]$/
        puts "Krivi format vremena"
        exit 1
      else
        s = t.to_i
        t = t[-1].chr
      end
      case t
      when 'm'
        s = s.minutes.ago
      when 'h'
        s = s.hours.ago
      when 'd'
        s = s.days.ago
      when 'M'
        s = s.months.ago
      when 'Y'
        s = s.years.ago
      end
      debug "from: #{s.to_i} (#{s})"
      tracks = get_tracks :to => s.to_i,
        :limit => ((ARGV[2] && ARGV[2].is_num?) ? ARGV[2] : 10)
    elsif ARGV[0] == "range" && ARGV[1] && ARGV[2]
      tracks = get_tracks :from => ARGV[1], :to => ARGV[2], :limit => 50
    end
    if tracks.nil? || tracks.empty?
      puts "(no tracks)"
    else
      puts tracks_to_s tracks[0..tracks.count - (tracks.last[:ts]==MAX_TS ? 2 : 1)]
    end
  else
    puts "ARG err"
  end
end
