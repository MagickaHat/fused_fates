#================================================================================================
# Pokémon Fused Fates Utilities/Debug - 001_Log.rb
#================================================================================================

#==================================================================
# module DevLog
#==================================================================
# @brief Leveled logging, timing and error guarding for plugin code.
# Console output only appears in debug mode; UtilitySettings::LOG_TO_FILE also writes to a file.
module DevLog
  LEVELS = { debug: 0, info: 1, warn: 2, error: 3, none: 4 }.freeze

  @once = {}   # Keys already reported by DevLog.once

  module_function

  # @brief Checks whether messages of a level are currently printed.
  # @param level [Symbol] :debug, :info, :warn or :error
  # @return [Boolean]
  def enabled?(level)
    return LEVELS[level].to_i >= LEVELS.fetch(UtilitySettings::LOG_LEVEL, 1)
  end

  # @brief Logs a message at the given level.
  # @param level [Symbol] :debug, :info, :warn or :error
  # @param msg [String]
  def log(level, msg)
    return if !enabled?(level)
    if $DEBUG && defined?(Console)
      case level
      when :warn  then Console.echo_warn(msg)
      when :error then Console.echo_error(msg)
      else             Console.echoln("[#{level}] #{msg}")
      end
    end
    write_file(level, msg) if UtilitySettings::LOG_TO_FILE
  end

  # @brief Logs a :debug message.
  def debug(msg); log(:debug, msg); end

  # @brief Logs an :info message.
  def info(msg); log(:info, msg); end

  # @brief Logs a :warn message.
  def warn(msg); log(:warn, msg); end

  # @brief Logs an :error message.
  def error(msg); log(:error, msg); end

  # @brief Logs a warning only the first time a key is seen (e.g. inside per-frame code).
  # @param key [Object] Anything identifying the message.
  # @param msg [String]
  def once(key, msg)
    return if @once[key]
    @once[key] = true
    log(:warn, msg)
  end

  # @brief Warns once that a method is deprecated.
  # @param old_name [String] The deprecated method.
  # @param new_name [String, nil] Its replacement.
  def deprecate(old_name, new_name = nil)
    msg = "#{old_name} is deprecated"
    msg += "; use #{new_name} instead" if new_name
    once([:deprecate, old_name], msg)
  end

  # @brief Runs a block and logs how long it took at :debug level.
  # @param label [String]
  # @return [Object] The block's result.
  def time(label)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ret = yield
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
    log(:debug, format("%s took %.2f ms", label, elapsed))
    return ret
  end

  # @brief Runs a block, logging and swallowing any StandardError it raises.
  # @param label [String] Describes what was being attempted.
  # @param fallback [Object] Returned if the block raises.
  # @return [Object] The block's result, or fallback.
  def guard(label, fallback = nil)
    return yield
  rescue StandardError => e
    log(:warn, "#{label}: #{e.class}: #{e.message}")
    log(:debug, e.backtrace[0, 5].join("\n")) if e.backtrace
    return fallback
  end

  # @brief Raises in debug mode (and logs otherwise) when a condition is false.
  # @param condition [Boolean]
  # @param msg [String]
  # @return [Boolean] The condition.
  def assert(condition, msg = "Assertion failed")
    return true if condition
    raise msg if $DEBUG
    log(:error, msg)
    return false
  end

  # @brief Creates a folder and any missing parent folders.
  # @param dir [String] e.g. "Debug/Bitmaps/"
  def ensure_dir(dir)
    path = ""
    dir.split("/").each do |part|
      next if part.empty?
      path = path.empty? ? part : "#{path}/#{part}"
      Dir.mkdir(path) if !File.directory?(path)
    end
  end

  # @brief Appends a line to UtilitySettings::LOG_FILE.
  def write_file(level, msg)
    ensure_dir(File.dirname(UtilitySettings::LOG_FILE))
    File.open(UtilitySettings::LOG_FILE, "ab") do |f|
      f.write("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} [#{level}] #{msg}\n")
    end
  rescue StandardError
    nil   # Logging must never crash the game (e.g. a read-only folder)
  end
end
