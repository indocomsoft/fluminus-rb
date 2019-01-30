# frozen_string_literal: true

module Fluminus
  # The Module class represents a module in LumiNUS
  class Module
    # Prevent direct class instantiation
    private_class_method :new

    def initialize(data)
      @data = data
    end

    def name
      @data['courseName']
    end

    def id
      @data['id']
    end

    def code
      @data['name']
    end

    def taking?
      !teaching?
    end

    def teaching?
      @data['access']['access_Create']
    end

    def self.from_api(data)
      return unless %w[access courseName id name].all? { |k| data&.key? k }

      new(data)
    end
  end
end
