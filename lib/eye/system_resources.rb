require 'celluloid'

class Eye::SystemResources

  # cached system resources
  class << self

    def memory(pid)
      if mem = cache.proc_mem(pid)
        mem.resident
      end
    end

    def cpu(pid)
      if cpu = cache.proc_cpu(pid)
        cpu.percent * 100
      end
    end

    def children(parent_pid)
      cache.children(parent_pid)
    end

    def start_time(pid) # unixtime
      if cpu = cache.proc_cpu(pid)
        cpu.start_time.to_i / 1000
      end
    end

    # total cpu usage in seconds
    def cputime(pid)
      if cpu = cache.proc_cpu(pid)
        cpu.total.to_f / 1000
      end
    end

    # last child in a children tree
    def leaf_child(pid)
      c = children(pid)
      return if c.empty?
      c += children(c.shift) while c.size > 1
      c[0]
    end

    def resources(pid)
      { :memory => memory(pid),
        :cpu => cpu(pid),
        :start_time => start_time(pid),
        :pid => pid
      }
    end

    def cache
      Celluloid::Actor[:system_resources_cache]
    end
  end

  class Cache
    include Celluloid

    attr_reader :expire

    def initialize
      @memory = {}
      @cpu = {}
      @ppids = {}
      clear
      setup_expire
    end

    def setup_expire(expire = 5)
      @expire = expire
      @timer.cancel if @timer
      @timer = every(@expire) { clear }
    end

    def clear
      @memory.clear
      @cpu.clear
      @ppids.clear
    end

    def proc_mem(pid)
      @memory[pid] ||= Eye::Sigar.proc_mem(pid) if pid

    rescue ArgumentError # when incorrect PID
    end

    def proc_cpu(pid)
      @cpu[pid] ||= Eye::Sigar.proc_cpu(pid) if pid

    rescue ArgumentError # when incorrect PID
    end

    def children(pid)
      if pid
        @ppids[pid] ||= Eye::Sigar.proc_list("State.Ppid.eq=#{pid}")
      else
        []
      end
    end
  end

  # Setup global sigar singleton here
  Cache.supervise_as(:system_resources_cache)
end
