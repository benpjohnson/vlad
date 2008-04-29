require 'singleton'

class Vlad
  VERSION = '1.0.0'

  include Singleton

  def initialize
    @roles = {}
    @env = {}

    instance_eval File.read("config/deploy.rb") if test ?f, 'config/deploy.rb'
  end

  def role name, host, args = nil
    @roles[name] = [host, args]
  end

  def set name, val = nil, &b
    @env[name] = val || b
  end

  def method_missing name, *other
    if @env.has_key? name and other.empty? then
      @env[name]
    else
      super
    end
  end
end
