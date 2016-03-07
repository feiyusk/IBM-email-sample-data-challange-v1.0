require 'nokogiri'
require 'mail'

module Message
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

      @account_from = Account::Account.new
      @account_to = account_to

      @html_part = CGI.unescapeHTML(text)
      @text_part = Nokogiri::HTML(@html_part).content




    end




  end

end