module NewRelic::Agent
  class StatsEngine
    module Shim # :nodoc:
      def add_sampler(*args); end
      def add_harvest_sampler(*args); end
      def spawn_sampler_thread(*args); end
    end
    
    module Samplers
      
      POLL_PERIOD = 10
      
      def spawn_sampler_thread
        
        return if !@sampler_process.nil? && @sampler_process == $$ 
        
        # start up a thread that will periodically poll for metric samples
        @sampler_thread = Thread.new do
          while true do
            begin
              sleep POLL_PERIOD
              poll periodic_samplers
            end
          end
        end
        @sampler_thread['newrelic_label'] = 'Sampler Tasks'
        @sampler_process = $$
      end
      
      # Add an instance of Sampler to be invoked about every 10 seconds on a background
      # thread.
      def add_sampler sampler
        periodic_samplers << sampler
        sampler.stats_engine = self
        log.debug "Adding sampler #{sampler.id.to_s}"
      end
      
      # Add a sampler to be invoked just before each harvest.
      def add_harvest_sampler sampler
        harvest_samplers << sampler
        sampler.stats_engine = self
        log.debug "Adding harvest time sampler: #{sampler.id.to_s}"
      end  
      
      private
      
      # Call poll on each of the samplers.  Remove
      # the sampler if it raises.
      def poll(samplers)
        samplers.delete_if do |sampled_item|
          begin 
            sampled_item.poll
            false # it's okay.  don't delete it.
          rescue Exception => e
            log.error "Removing #{sampled_item} from list"
            log.error e
            log.debug e.backtrace.to_s
            true # remove the sampler
          end
        end
      end
      
      def harvest_samplers
        @harvest_samplers ||= []
      end
      def periodic_samplers
        @periodic_samplers ||= []
      end
    end
  end
end
