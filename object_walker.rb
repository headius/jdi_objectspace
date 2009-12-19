# object_walker.rb
require 'java'
require 'jruby/util'

module ObjectWalker
  import com.sun.jdi.Bootstrap
  
  # Given a Ruby class, walk all live instances of that class
  def self.walk_objects(cls, &block)
    # get all RubyObject instances
    class_ref = VM.classes_by_name('org.jruby.RubyObject')[0]
    object_refs = class_ref.instances(0)
    
    # get the current thread reference for the debugger
    curr_thread_name = java.lang.Thread.current_thread.name
    curr_thread_ref = VM.all_threads.select {|thread| thread.name == curr_thread_name}
  
    # make sure the hook class has been loaded
    org.jruby.ObjectYieldHook
    
    # set up a "method entry" event request for the hook class
    hook_class = VM.classes_by_name('org.jruby.ObjectYieldHook')[0]
    event_mgr = VM.event_request_manager
    request = event_mgr.create_method_entry_request
    request.add_class_filter hook_class
    request.suspend_policy = com.sun.jdi.request.EventRequest::SUSPEND_EVENT_THREAD
    request.enable

    # separate thread do to the object walking
    walker = Thread.new do
      begin
        # for each object ref, expect a method entry event
        object_refs.each do |object_ref|
          event_set = VM.event_queue.remove
          event_set.each do |event|
            # for each method entry, mutate the stack frame to hold a new reference
            thread = event.thread
            frame = thread.frame(0)
            frame.set_value(frame.visible_variable_by_name('obj'), object_ref)
            thread.resume
          end
        end
      rescue Exception => e
        p e
      end
    end
    
    # for as many objects, call the hook method
    object_refs.size.times {JRuby::Util.yield_once(cls, &block)}
  end
    
  # Initialize the singleton VirtualMachine reference
  def self.init_vm
    raise "Already initialize" if defined? VM
    vmm = Bootstrap.virtual_machine_manager
    sock_conn = vmm.attaching_connectors[0] # not guaranteed to be Socket
    args = sock_conn.default_arguments
    args['port'].value = "12345"
    vm = sock_conn.attach(args)
  end
  
  VM ||= init_vm
end