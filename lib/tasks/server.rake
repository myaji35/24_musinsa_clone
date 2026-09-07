# Server management tasks
namespace :server do
  desc "Clean stale PID files"
  task :clean_pids do
    pid_dir = Rails.root.join("tmp", "pids")

    Dir.glob(pid_dir.join("*.pid")).each do |pid_file|
      pid = File.read(pid_file).strip.to_i

      begin
        # Check if process is running
        Process.kill(0, pid)
        puts "✓ Process #{pid} is running (#{File.basename(pid_file)})"
      rescue Errno::ESRCH
        # Process not found, remove stale PID file
        File.delete(pid_file)
        puts "✗ Removed stale PID file: #{File.basename(pid_file)} (process #{pid} not running)"
      rescue Errno::EPERM
        # Process exists but no permission to signal
        puts "⚠ Process #{pid} exists but permission denied (#{File.basename(pid_file)})"
      end
    end
  end

  desc "Stop all Rails server processes"
  task :stop do
    pid_file = Rails.root.join("tmp", "pids", "server.pid")

    if File.exist?(pid_file)
      pid = File.read(pid_file).strip.to_i

      begin
        Process.kill("TERM", pid)
        puts "✓ Stopped Rails server (PID: #{pid})"
        File.delete(pid_file)
      rescue Errno::ESRCH
        puts "✗ Process #{pid} not found, removing stale PID file"
        File.delete(pid_file)
      rescue Errno::EPERM
        puts "⚠ Permission denied to stop process #{pid}"
      end
    else
      puts "No server.pid file found"
    end
  end

  desc "Restart Rails server (stop and start)"
  task restart: [ :stop ] do
    puts "Starting Rails server..."
    exec "bin/rails server"
  end
end
