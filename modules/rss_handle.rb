require 'simple-rss'
require 'open-uri'
require 'mail'
require 'nokogiri'
require 'faker'

class Array
  def odd_values
    self.values_at(* self.each_index.select {|i| i.odd?})
  end
  def even_values
    self.values_at(* self.each_index.select {|i| i.even?})
  end
end

module RSSHandle

  class Account

    attr_reader :name, :email

    def to_s
      "#{@name} <#{@email}>"
    end

    def print_for_html
      @name + ' &lt;<a href=' + 'mail_to:"' + @email + '" target="_blank">'  + @email + '</a>&gt;'
    end

    private

    def initialize
      @name = Faker::Name.name
      @email = Faker::Internet.email
    end


  end

  class Getter
    attr_reader :thread
    # class in charge of getting the RSS feeds


    private


    def initialize url, account
      puts "getting feeds from: #{url}"

      @account = account

      @url = url

      @thread = Thread.new account

      # first adding feeds
      rss.feed.items.each do |item|
        @thread.add item
      end

      @thread.build

      @thread.write_emls



    end

    def rss
      @rss ||= SimpleRSS.parse open(@url)
    end



  end


  class FeedHandler

    def subject
      @item.title
    end

    def sent_at
      @item.published || @item.pubDate
    end

    def text
      @item.summary || @item.description
    end

    def user
      @item.dc_creator || @item.author
    end

    private

    def initialize item
      @item = item
    end
  end

  class Thread

    def add item

      feed = FeedHandler.new item
      message = Message.new feed.subject, feed.sent_at, feed.text, @account

      @messages << message

    end


    def build

      @messages = @messages.sort_by{|m| m.created_at }

      if unrelated_feeds?
        all_messages_are_incoming
      else
        build_email_tree
      end
    end

    def write_emls
      @incoming_messages.each do |message|
        message.write_eml
      end
    end


    private





    def add_email_history_for_html

      @messages.each_with_index do |m, i|

        text_to_add_html = "<br><br>On #{m.created_at}, #{m.account_from.print_for_html} wrote: <blockquote>" + m.html_part

        m.html_part += @history_html + "</blockquote>" * i

        @history_html =  text_to_add_html + @history_html

      end

    end

    def add_email_history_for_plain_text

      @messages.each_with_index do |m, i|


        text_to_add = "\n\nOn #{m.created_at}, #{m.account_from} wrote:\n" +  ("\n" + m.text_part).gsub("\n", "\n>")

        m.text_part += @history_text

        @history_text =  text_to_add + @history_text

        # adding '>' for text in history
        @history_text.gsub!("\n", "\n>")
      end

    end

    def add_email_history

      add_email_history_for_plain_text

      add_email_history_for_html

    end


    def change_subjects
      @messages.each_with_index do |m,i|

        # changing subject only for
        if m != starting_message
          m.subject = "Re: " + starting_message.subject
        end
      end
    end

    def select_incoming_messages

      @messages.odd_values.each do |m|
        @incoming_messages << m
      end

    end




    def set_email_from_for_outgoing_messages
      # all messages that not incoming are outgoing
      outgoing_messages.each do |m|
        m.account_from = @account
      end
    end

    def set_email_from_for_incoming_messages

      partner = Account.new

      # all messages that not incoming are outgoing
      @incoming_messages.each do |m|
        m.account_from =  partner
      end
    end


    def outgoing_messages
      @messages.reject{|m| @incoming_messages.include? m }
    end


    def build_email_tree

      change_subjects

      select_incoming_messages

      set_email_from_for_incoming_messages

      set_email_from_for_outgoing_messages



      add_email_history

    end

    def unrelated_feeds?
      @messages.select{|m| m.subject.include? "Re:" or m.subject.include? "Answer by"}.empty? #and participants.count > 1
    end

    def starting_message
      @start ||= @messages.reject{|m| m.subject.include? "Re:" or m.subject.include? "Answer by"}.first
    end

    def all_messages_are_incoming
      @messages.each do |m|
        @incoming_messages << m
      end
    end





    def initialize account
      @incoming_messages = []

      @messages = []


      @account = account

      @history_text = ""
      @history_html = ""

    end




  end


  class Message

    attr_reader  :created_at
    attr_accessor :html_part, :text_part, :subject, :account_from, :account_to

    @@count = 0

    def write_eml

      title = @subject
      text = @text
      send_at = @created_at



      attached_file_flag = false

      dummy_filename = nil

      account_to = @account_to
      account_from = @account_from

      mail = Mail.new do
        date send_at
        to      account_to #"#{account_to.name} <#{account_to.email}>"
        from    account_from #
        subject title



        # creating dummy file to attach
        if @@count == 1
          attached_file_flag = true

          n = 1
          dummy_filename = "./file-#{n}M.txt"
          f = File.open(dummy_filename, "w") do |f|
            contents = "x" * (1024*1024)
            n.to_i.times { f.write(contents) }
          end

          add_file dummy_filename


        end


      end

      message_txt = @text_part

      text_html = @html_part

      text_part = Mail::Part.new do

        body message_txt
      end

      html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body text_html
      end


      mail.text_part = text_part
      mail.html_part = html_part




      File.open("./output/#{@count}.eml", 'w') { |file| file.write(mail.to_s) }

      # erasing dummy file
      if attached_file_flag
        File.delete(dummy_filename)
      end

    end




    private

    def initialize subject, created_at, text, account_to
      @@count += 1

      @count = @@count
      @subject = subject
      @created_at = created_at
      @text = text

      @account_from = Account.new
      @account_to = account_to

      @html_part = CGI.unescapeHTML(text)
      @text_part = Nokogiri::HTML(@html_part).content




    end




  end


end
