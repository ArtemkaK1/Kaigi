require "fileutils"
require "openssl"

module MeetrailCI
  ROOT = File.expand_path("..", __dir__)
  OUTPUT = File.join(ROOT, "build", "testflight")

  def self.required(name)
    value = ENV[name].to_s.strip
    raise "Missing #{name}" if value.empty?
    value
  end

  def self.validate_release_context!
    raise "Publish only through the manually dispatched main workflow" unless
      ENV["GITHUB_ACTIONS"] == "true" && ENV["GITHUB_EVENT_NAME"] == "workflow_dispatch" &&
      ENV["GITHUB_REF"] == "refs/heads/main"
    raise "Unexpected APPLE_TEAM_ID" unless required("APPLE_TEAM_ID") == "WX557M9HD2"
    raise "Unexpected APP_IDENTIFIER" unless required("APP_IDENTIFIER") == "com.volrik.meetrail"
    raise "Invalid ASC_KEY_ID" unless required("ASC_KEY_ID").match?(/\A[A-Z0-9]{10}\z/)
    raise "A Team API Key issuer UUID is required" unless required("ASC_ISSUER_ID").match?(
      /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    )
  end

  # Independent of ASC's processing delay; reruns of the same workflow get a new suffix.
  # Fail closed if a previous, out-of-band numbering scheme is ahead of this sequence.
  def self.build_number(latest, run_id, attempt)
    raise "Expected an integer TestFlight build number" unless latest.to_s.match?(/\A\d+\z/)
    raise "Invalid GitHub run ID" unless run_id.to_s.match?(/\A[1-9]\d*\z/)
    raise "GitHub run attempt must be 1..999" unless attempt.to_s.match?(/\A[1-9]\d*\z/) && attempt.to_i < 1000
    candidate = run_id.to_i * 1000 + attempt.to_i
    raise "Build number exceeds 18 digits" if candidate.to_s.length > 18
    raise "Existing TestFlight build is ahead of the GitHub run sequence; review numbering before publishing" unless candidate > latest.to_i
    candidate.to_s
  end

  def self.with_key
    path = required("ASC_API_KEY_PATH")
    stage("Temporary API key preparation") do
      key = ENV["ASC_API_KEY_P8"].to_s
      raise "Missing ASC_API_KEY_P8" if key.strip.empty?
      parsed = OpenSSL::PKey.read(key)
      raise "Expected an App Store Connect EC private key" unless
        parsed.is_a?(OpenSSL::PKey::EC) && parsed.private? && parsed.group.curve_name == "prime256v1"
      raise "Temporary API key must have permissions 600" unless File.stat(path).mode & 0o777 == 0o600
      raise "Temporary API key differs from ASC_API_KEY_P8" unless File.binread(path) == key
    end
    yield path
  ensure
    FileUtils.rm_f(path) if path
  end

  def self.summary(message)
    File.open(ENV["GITHUB_STEP_SUMMARY"], "a") { |file| file.puts(message) } if ENV["GITHUB_STEP_SUMMARY"]
  end

  def self.stage(name)
    puts "::group::#{name}" if ENV["GITHUB_ACTIONS"] == "true"
    result = yield
    summary("- #{name}: succeeded.")
    result
  rescue StandardError
    summary("- #{name}: **failed**. Subsequent stages were not run.")
    raise
  ensure
    puts "::endgroup::" if ENV["GITHUB_ACTIONS"] == "true"
  end
end
