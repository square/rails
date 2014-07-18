require 'abstract_unit'
require 'ostruct'
require 'rails/commands/dbconsole'

# This is a semi-backport from 4.0 but unfortunately 3.2's DBConsole is much
# harder to test cleanly :(
class Rails::DBConsoleTest < ActiveSupport::TestCase

  CONFIG_WITHOUT_SHARDS = {
    "adapter"=> "mysql",
    "host"=> "master",
    "database"=> "foo_test",
    "user"=> "foo",
  }

  CONFIG_WITH_SHARDS = CONFIG_WITHOUT_SHARDS.merge({
    "multidb"=> {
      "databases"=> {
        "replica1"=> {
          "host"=> "replica1host"
        },
        "replica2"=> {
          "host"=> "replica2host"
        }
      }
    }
  })

  def test_shard_defaults_to_replica
    app_db_config(CONFIG_WITH_SHARDS)
    start
    assert !aborted, output
    assert_equal %w(--host=replica1host foo_test), db_args
  end

  def test_shard_from_args
    app_db_config(CONFIG_WITH_SHARDS)
    start(%w(--shard replica2))
    assert !aborted, output
    assert_equal %w(--host=replica2host foo_test), db_args
  end

  def test_invalid_shard_arg
    app_db_config(CONFIG_WITH_SHARDS)
    start(%w(--shard NONEXISTENT))
    assert !aborted, output
    assert_equal %w(--host=replica1host foo_test), db_args
  end

  def test_master_shard_arg
    app_db_config(CONFIG_WITH_SHARDS)
    start(%w(--shard master))
    assert !aborted, output
    assert_equal %w(--host=master foo_test), db_args
  end

  def test_shard_ignored_without_shard_config
    app_db_config(CONFIG_WITHOUT_SHARDS)
    start(%w(--shard replica1))
    assert !aborted, output
    assert_equal %w(--host=master foo_test), db_args
  end

  attr_reader :aborted, :output
  private :aborted, :output

  private

  def app_db_config(config)
    @app = OpenStruct.new(
      config: OpenStruct.new(
        database_configuration: {
          Rails.env => config
        }
      )
    )
  end

  def dbconsole
    @dbconsole ||= Rails::DBConsole.new(@app)
  end

  def start(argv = [])
    Rails::DBConsole.send(:remove_const, 'ARGV') if Rails::DBConsole.const_defined?('ARGV', false)
    Rails::DBConsole.const_set('ARGV', argv)
    capture_exec { dbconsole.start }
  end

  def capture_exec
    @aborted = false
    $exec_args = nil
    dbconsole.instance_eval do
      def exec(*args)
        puts "exec in #{self} with #{args.inspect}"
        $exec_args = args
      end
    end
    @output = capture(:stderr) do
      begin
        yield
      rescue SystemExit
        @aborted = true
      end
    end
  end

  # Ignore the executable
  def db_args
    $exec_args[1..-1] if $exec_args
  end
end
