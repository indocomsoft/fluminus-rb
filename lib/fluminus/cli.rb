# frozen_string_literal: true

require 'io/console'

module Fluminus
  # The CLI is a class responsible of handling all the command line interface
  # logic.
  class CLI
    def initialize(args = [])
      @args = args
    end

    def run
      username, password = ask_username_password
      @api = Fluminus::API.new
      puts('Invalid credentials') unless @api.authenticate(username, password)
      puts("Hi #{@api.name}!")
      print_modules
    end

    private

    def print_modules
      modules = @api.modules
      modules_taking = modules.filter(&:taking?)
      modules_teaching = modules.filter(&:teaching?)
      puts 'You are taking these modules:'
      puts(modules_taking.map { |m| "- #{m.code} #{m.name}" })
      puts 'And teaching:'
      puts(modules_teaching.map { |m| "- #{m.code} #{m.name}" })
    end

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
