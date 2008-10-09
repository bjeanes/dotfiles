require 'irb/completion'
require 'map_by_method'
require 'what_methods'
require 'pp'
IRB.conf[:AUTO_INDENT]=true

class Object
  # Return a list of methods defined locally for a particular object.  Useful
  # for seeing what it does whilst losing all the guff that's implemented
  # by its parents (eg Object).
  def local_methods(obj = self)
    (obj.methods - obj.class.superclass.instance_methods).sort
  end
end

require 'wirble'
Wirble.init
Wirble.colorize