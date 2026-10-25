require_relative "ci_support"
require "tmpdir"

# Expected failures in these tests must not become release-stage failures in the
# real GitHub summary. Environment changes are confined to this test process.
ENV.delete("GITHUB_STEP_SUMMARY")
ENV.delete("GITHUB_ACTIONS")

def rejects(error_type = RuntimeError)
  yield
rescue error_type
  return
else
  raise "Expected a fail-closed validation error"
end

first = MeetrailCI.build_number(0, "12345678901", "1")
retry_number = MeetrailCI.build_number(0, "12345678901", "2")
next_run = MeetrailCI.build_number(first, "12345678902", "1")
raise "Duplicate rerun number" unless retry_number.to_i > first.to_i
raise "Next run did not increase" unless next_run.to_i > retry_number.to_i
rejects { MeetrailCI.build_number(first, "12345678901", "1") }
rejects { MeetrailCI.build_number("1.2", "12345678901", "1") }
rejects { MeetrailCI.build_number(0, "bad", "1") }
rejects { MeetrailCI.build_number(0, "12345678901", "1000") }
rejects { MeetrailCI.build_number(0, "1234567890123456", "1") }
original_ref = ENV["GITHUB_REF"]
original_event = ENV["GITHUB_EVENT_NAME"]
begin
  ENV["GITHUB_ACTIONS"] = "true"
  ENV["GITHUB_EVENT_NAME"] = "workflow_dispatch"
  ENV["GITHUB_REF"] = "refs/heads/untrusted"
  rejects { MeetrailCI.validate_release_context! }
ensure
  ENV.delete("GITHUB_ACTIONS")
  ENV["GITHUB_EVENT_NAME"] = original_event
  ENV["GITHUB_REF"] = original_ref
end
# Cleanup must also run when raw-key validation fails. This is invalid text,
# never a generated credential; the shell must preserve its newlines verbatim.
original = ENV["ASC_API_KEY_P8"]
original_path = ENV["ASC_API_KEY_PATH"]
begin
  Dir.mktmpdir("meetrail-key-test-") do |directory|
    ENV["ASC_API_KEY_P8"] = "invalid\nmultiline text\n"
    ENV["ASC_API_KEY_PATH"] = File.join(directory, "AuthKey.p8")
    raise "Key-file write failed" unless system("/bin/bash", "-c", <<~'SHELL')
      set -euo pipefail
      umask 077
      printf '%s' "$ASC_API_KEY_P8" > "$ASC_API_KEY_PATH"
      chmod 600 "$ASC_API_KEY_PATH"
    SHELL
    raise "Raw multiline content changed" unless File.binread(ENV["ASC_API_KEY_PATH"]) == ENV["ASC_API_KEY_P8"]
    raise "Incorrect key-file permissions" unless File.stat(ENV["ASC_API_KEY_PATH"]).mode & 0o777 == 0o600
    rejects(OpenSSL::PKey::PKeyError) { MeetrailCI.with_key { raise "Must not reach the signing stage" } }
    raise "Temporary key file leaked" if File.exist?(ENV["ASC_API_KEY_PATH"])
  end
ensure
  ENV["ASC_API_KEY_P8"] = original
  ENV["ASC_API_KEY_PATH"] = original_path
end
puts "PASS: build numbering, release guard, raw multiline key handling, permissions and failure cleanup"
