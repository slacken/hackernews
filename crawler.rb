# hacker news crawler

require 'mongoid'
require 'open-uri'

class News
  include Mongoid::Document
  field :_id, type: Integer
  field :title
  field :url
  field :created_at, type: Date
  field :points, type: Integer, default: 0
  field :comments, type: Integer, default: 0
  field :local, type: Boolean, default: false

  validates :title, :url, presence: true

  @@now = Time.now

  class << self
    def parse_date(string) # 4 hours ago
      match = string.match(/([\d]{1,4}) (hour|day|minute)s? ago/)
      if match.nil?
        nil
      else
        @@now - match[1].to_i.send(match[2])
      end
    end

    def parse_comments(string)
      match = string.match(/([\d]{1,4}) comment[s]?/)
      match ? match[1].to_i : 0
    end

    def fetch(url)
      more_rexp = %r{<td class="title"><a href="([\S]*?)" rel="nofollow">More</a></td>}
      news_rexp = %r{<tr><td align=right valign=top class="title">[\d]{1,8}\.</td><td><center>[\s\S]*?</center></td><td class="title"><a href="([\s\S]*?)"( rel="nofollow")?>([\s\S]*?)</a>[\s\S]*?<span id=score_([\d]{1,7})>([\d]{1,4}) point[s]?</span>[\s\S]*?</a> ([\s\S]*?)  \| <a href="item\?id=[\d]{1,7}">([\s\S]*?)</a></td></tr><tr style="height:5px"></tr>}
      content = ''
      while true
        begin
          content = open(url){|f| f.read }
        rescue Exception => e
          print "*"
          sleep(30)
        else
          break
        end
      end
      return false if content.include?('Unknown or expired link.')
      news = []
      content.gsub(news_rexp) do
        item = {}
        item[:url], item[:title], item[:_id], item[:points] = $1, $3, $4.to_i, $5.to_i
        if item[:url].start_with?('item?id=')
          item[:url] = 'https://news.ycombinator.com/' + item[:url]
          item[:local] = true
        end
        item[:created_at], item[:comments] = parse_date($6), parse_comments($7)
        news << item
      end
      next_url = (content.match(more_rexp) || [])[1]
      next_url = 'https://news.ycombinator.com' + next_url if next_url
      [news, next_url]
    end

    def start(url)
      news, next_url = fetch(url)
      collection.insert(news) if news
      if next_url
        puts "#{url}: #{news.count}"
        sleep(rand(8..12))
        start(next_url)
      end
    end
  end
end
Mongoid.load!("mongoid.yml", :best)
# puts News.fetch('https://news.ycombinator.com/newest')
# News.start('https://news.ycombinator.com/newest') # https://news.ycombinator.com/news2
# News.start('https://news.ycombinator.com/best')
# puts News.delete_all # 1431