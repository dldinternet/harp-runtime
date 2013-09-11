# Author::    John Gardner
# Copyright:: Copyright (c) 2013 Transcend Computing
# License::   ASLV2
require "shikashi"
require "harp-runtime/cloud/cloud_mutator"

module SandboxModule
  extend self

  DIE = "die"
  @interpreter = nil

  def set_engine(engine)
    @interpreter = engine
  end

  def engine()
    @interpreter
  end

  def die()
    return DIE
  end

  def self.method_added(method_name)
    Logging.logger['SandboxModule'].debug "Adding #{method_name.inspect}"
  end
end

module Harp
# The interpreter reads in the template, and makes itself available as engine()
# with the scope of the template.  All resource operations are proxied through
# this object.
class HarpInterpreter

  include Shikashi

  @@logger = Logging.logger[self]

  def initialize(context)
    @created = []
    @destroyed = []
    @updated = []
    @navigate = []
    @resourcer = Harp::Resourcer.new
    @mutator = Harp::Cloud::CloudMutator.new(context)
    @program_counter = 0
    @is_debug = (context.include? :debug) ? true : false
    @break_at = (context.include? :break) ? context[:break] : nil
  end

  # Accept the resources from a template and add to the dictionary of resources
  # available to the template.
  def consume(template)
    if ! advance() then return self end
    @resourcer.consume(template)
    return self
  end

  # Create a resource and wait for the resource to become available.
  def create(resource_name)
    if ! advance() then return self end
    @@logger.debug "Launching resource: #{resource_name}."
    resource = @resourcer.get resource_name
    @mutator.create(resource_name, resource)
    @created.push(resource_name)
    return self
  end

  # Create a set of resources; all resources must will be complete before
  # processing continues.
  def createParallel(*resources)
    if ! advance() then return self end
    @@logger.debug "Launching resource(s) in parallel #{resources.join(',')}."
    @created += resources
    return self
  end

  # Update a resource to a new resource definition.
  def update(resource)
    if ! advance() then return self end
    @@logger.debug "Updating resource: #{resource}."
    @updated.push(resource)
    return self
  end

  # Update a set of resources in parallel to new resource definitions.
  def updateParallel(*resources)
    if ! advance() then return self end
    @@logger.debug "Updating resource(s) in parallel #{resources.join(',')}."
    @updated += resources
    return self
  end

  # Update a resource to an alternate definition.
  def updateTo(resource_start, resource_finish)
    if ! advance() then return self end
    @@logger.debug "Updating resource: #{resource_start} to #{resource_finish}."
    @updated.push(resource_finish)
    return self
  end

  # Destroy a named resource.
  def destroy(resource)
    if ! advance() then return self end
    @@logger.debug "Destroying resource: #{resource}."
    @destroyed.push resource
    return self
  end

  # Destroy a named resource.
  def destroyParallel(*resources)
    if ! advance() then return self end
    @@logger.debug "Destroying resource(s) in parallel #{resources.join(',')}."
    @destroyed += resources
    return self
  end

  def onFail(*fails)
    if ! advance() then return self end
    @@logger.debug "Handle fail action: #{fails.join(',')}"
    return self
  end

  # Interpreter debug operation; break at current line.
  def break
    if ! advance() then return self end
    @@logger.debug "Handle break."
    @navigate.push "Break at line #{@program_counter}"
    @break_at = @program_counter
    return self
  end

  # Interpreter debug operation; continue running from a break.
  def continue
    if ! advance() then return self end
    @@logger.debug "Handle continue."
    @navigate.push "Continue at line #{@program_counter}"
    @break_at = nil
    return self
  end

  # Interpreter debug operation; step over a single operation.
  def step
    if ! advance() then return self end
    @@logger.debug "Handle step."
    @navigate.push "Step at line #{@program_counter}"
    @break_at += 1
    return self
  end

  def play(lifecycle, options)

    harp_file = options[:harp_file] || nil
    harp_contents = options[:harp_contents] || nil

    if harp_file != nil
      file = File.open(harp_file, "rb")
      harp_contents = file.read
    end

    s = Sandbox.new
    priv = Privileges.new
    priv.allow_method :print
    priv.allow_method :puts
    priv.allow_method :engine
    priv.allow_method :die

    priv.instances_of(HarpInterpreter).allow_all

    SandboxModule.set_engine(self)
    s.run(priv, harp_contents, :base_namespace => SandboxModule)

    # Now, instrument the script for debugging.

    # Call create/delete etc., as defined in harp file
    if SandboxModule.method_defined? lifecycle
      @@logger.debug "Invoking lifecycle: #{lifecycle.inspect}."
      @@logger.debug "Invoking: #{SandboxModule.method(lifecycle)}."
      SandboxModule.method(lifecycle).call()
    else
      raise "No lifecycle method #{lifecycle.inspect} defined in harp."
    end

    respond
  end

  private

  def respond
    done = []
    @created.each do |createe|
      done.push ({ "create" => "created #{createe}" })
    end
    @updated.each do |updatee|
      done.push ({ "update" => "updated #{updatee}" })
    end
    @destroyed.each do |destroyee|
      done.push ({ "destroy" => "destroyed #{destroyee}" })
    end
    @navigate.each do |nav|
      done.push ({ "nav" => "#{nav}" })
    end
    if @is_debug
      done.push ({ "token" => "pc:#{@program_counter}" })
    end
    done
  end

  # Advance the program counter to the next instruction.
  def advance
    if ! @break_at.nil?
      if @break_at >= @program_counter
        return false
      end
    end
    @program_counter += 1
    return true
  end

end

end