require "colored"

module Snap
  module VBox
    class SnapShot #{{{
      @@snaps = []
      class << self
        def is_endnode?() @@current.uuid == @@snaps.last.uuid end

        def snaps() @@snaps end 

        def parse_tree(vmname)
          vm = VirtualBox::VM.find( vmname )
          @@current = vm.current_snapshot
          @@indent = ""
          return unless @@current
          _parse(vm.root_snapshot)
        end

        # [TODO] need refactoring
        def time_elapse(time)
          _sec  = 1
          _min  = _sec * 60
          _hour = _min * 60
          _day  = _hour * 24

          sec = time.to_i
          min = sec / _min
          hour = sec / _hour
          day  = sec / _day

          case
          when day  > 0 then "#{day} day#{day == 1 ? '' : 's'}"
          when hour > 0 then "#{hour} hour#{hour == 1 ? '' : 's'}"
          when min  > 0 then "#{min} minute#{min == 1 ? '' : 's'}"
          when sec  > 0 then "#{sec} second#{sec == 1 ? '' : 's'}"
          end
        end

        ## [TODO] darty hack, should be written more simply
        def _parse(snaps, guide = "")
          @@snaps << snaps.name
          time = time_elapse(Time.now - snaps.time_stamp)
          snapinfo = "#{snaps.name} [ #{time} ]"
          snapinfo = snapinfo.yellow  if snaps.uuid == @@current.uuid
          result = "#{guide} #{snapinfo}"
          result << " #{snaps.description}" unless snaps.description.empty?
          result << "\n"
          snaps.children.each_with_index do |e, idx|
            tmp = guide.chop.chop + "   "
            nextguide = if snaps.children.size == idx + 1
                          tmp = tmp.sub("`", " ")
                          "`"
                        else
                          "|"
                        end
            tmp << nextguide << "--"
            result <<  _parse(e, "#{tmp}")
          end
          result
        end
      end
    end #}}}
  end
	class Command < Vagrant::Command::GroupBase
	  register "snap","Manages a snap"

    no_tasks {
      def env
        @_env ||= Vagrant::Environment.new
      end

      def with_target(target, &blk)
        target_found = false
        env.vms.each do |name, vm|
          vagvmname = vm.name
          vmname = vm.vm.name
          if target
            blk.call(vmname, vagvmname) if target.to_sym == vagvmname
            target_found = true
          else
            blk.call(vmname, vagvmname)
            target_found = true
          end
        end
        warn "you need to select collect vmname" unless target_found
      end
    }

	  desc "list", "list snapshot"
	  def list(target=nil)
      with_target(target) do |vmname, vagvmname|
        puts "[#{vagvmname}]"
        result = VBox::SnapShot.parse_tree( vmname )
        puts result ? result : "no snapshot"
      end
	  end

	  desc "go SNAP_NAME", "go to specified snapshot"
	  def go(snapshot_name, target=nil)
      with_target(target) do |vmname, vagvmname|
        puts "[#{vagvmname}]"
        system "VBoxManage controlvm #{vmname} poweroff"
        system "VBoxManage snapshot  #{vmname} restore #{snapshot_name}"
        system "VBoxManage startvm   #{vmname} --type headless"
      end
	  end

	  desc "back", "back to current snapshot"
	  def back(target=nil)
      with_target(target) do |vmname, vagvmname|
        puts "[#{vagvmname}]"
        system "VBoxManage controlvm #{vmname} poweroff"
        system "VBoxManage snapshot  #{vmname} restorecurrent"
        system "VBoxManage startvm   #{vmname} --type headless"
      end
	  end

	  desc "take [NAME] [-d DESC]", "take snapshot"
    method_option :desc, :type => :string, :aliases => "-d"
	  def take(target=nil)
      with_target(target) do |vmname, vagvmname|
        puts "[#{vagvmname}]"
        VBox::SnapShot.parse_tree( vmname )
        last_name = VBox::SnapShot.snaps.sort.reverse.first
        new_name = last_name.nil? ? "#{vagvmname}-01" : last_name.succ
        desc = options.desc ? " --description '#{options.desc}'" : ""
        system "VBoxManage snapshot #{vmname} take #{new_name} #{desc} --pause"
      end
	  end

	  desc "delete SNAP_NAME", "delete snapshot"
	  def delete(snapshot_name, target=nil)
      with_target(target) do |vmname, vagvmname|
        puts "[#{vagvmname}]"
        system "VBoxManage snapshot #{vmname} delete #{snapshot_name}"
      end
	  end
	end
end
