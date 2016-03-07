require 'faker'
require 'fileutils'


module Account
  class Account

    attr_reader :name, :email

    def to_s
      "#{@name} <#{@email}>"
    end

    def print_for_html
      @name + ' &lt;<a href=' + 'mail_to:"' + @email + '" target="_blank">'  + @email + '</a>&gt;'
    end

    def create_inbox_folder path
      FileUtils::mkdir_p inbox_path(path)
    end

    def inbox_path path = nil
      @inbox_path ||= "#{path}/#{@email}"
    end

    def domain
      @email.split("@").last
    end



    private

    def initialize
      @inbox_path = nil
      @name = Faker::Name.name
      @email = Faker::Internet.email
    end


  end


end
