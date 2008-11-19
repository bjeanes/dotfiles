# require 'wirble'
require 'rubygems'
require 'wirble'

__wirble_colors = {
  # delimiter colors
  :comma              => :white,
  :refers             => :white,

  # container colors (hash and array)
  :open_hash          => :white,
  :close_hash         => :white,
  :open_array         => :white,
  :close_array        => :white,

  # object colors
  :open_object        => :light_red,
  :object_class       => :red,
  :object_addr_prefix => :blue,
  :object_line_prefix => :blue,
  :close_object       => :light_red,

  # symbol colors
  :symbol             => :blue,
  :symbol_prefix      => :blue,

  # string colors
  :open_string        => :light_green,
  :string             => :light_green,
  :close_string       => :light_green,

  # misc colors
  :number             => :light_blue,
  :keyword            => :orange,
  :class              => :red,
  :range              => :light_blue,
}

Wirble.init(:history_size => 10000)
Wirble.colorize

Wirble::Colorize.colors = __wirble_colors


class Object
  # Return a list of methods defined locally for a particular object.  Useful
  # for seeing what it does whilst losing all the guff that's implemented
  # by its parents (eg Object).
  def local_methods(obj = self)
    (obj.methods - obj.class.superclass.instance_methods).sort
  end
end