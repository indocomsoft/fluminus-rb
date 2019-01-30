require 'io/console'

module Fluminus
  class CLI
    def initialize(args = [])
      @args = args
    end

    def run
      username, password = ask_username_password
      api = Fluminus::API.new
      puts('Invalid credentials') unless api.authenticate(username, password)
      puts("Hi #{api.name}!")
      puts 'You are taking these modules:'
      puts api.modules_taking.map { |m| "- #{m['name']} #{m['courseName']}" }
      puts 'And teaching:'
      puts api.modules_teaching.map { |m| "- #{m['name']} #{m['courseName']}" }
    end

    private

    def ask_username_password
      print('username: ')
      username = STDIN.gets.chomp
      print('password: ')
      password = STDIN.noecho(&:gets).chomp
      puts
      [username, password]
    end
  end
end
