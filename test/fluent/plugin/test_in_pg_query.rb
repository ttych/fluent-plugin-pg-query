# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/in_pg_query'

class PgQueryInputTest < Test::Unit::TestCase
  BASE_CONF = [
    'database test'
  ].freeze
  SQL_QUERY = 'select * from data'
  QUERY_CONF = [
    '<query>',
    "sql #{SQL_QUERY}",
    '</query>'
  ].freeze

  TEST_TIME = Time.parse('2025-01-01T00:00:00.000Z')

  setup do
    Fluent::Test.setup
  end

  sub_test_case 'configuration' do
    test 'default configuration' do
      driver = create_driver
      input = driver.instance

      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_TAG, input.tag

      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_INTERVAL, input.interval

      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_HOST, input.host
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_PORT, input.port
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_USER, input.user
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_PASSWORD, input.password
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_CONNECT_TIMEOUT, input.connect_timeout
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_SSLMODE, input.sslmode
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_TRY_COUNT, input.try_count
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_PG_TRY_DELAY, input.try_delay
      assert_equal Fluent::Plugin::PgQueryInput::DEFAULT_CA_CERT, input.ca_cert
    end

    sub_test_case 'postgresql connection' do
      test 'port should be valid' do
        test_conf = generate_conf(extra_conf: ['port -1'])

        assert_raise(Fluent::ConfigError) do
          create_driver(test_conf)
        end
      end

      test 'database should not be empty' do
        test_conf = generate_conf(base_conf: BASE_CONF.reject { |conf_item| conf_item.start_with?('database ') })

        assert_raise(Fluent::ConfigError) do
          create_driver(test_conf)
        end
      end

      test 'connect_timeout should be positive' do
        test_conf = generate_conf(extra_conf: ['connect_timeout -1'])

        assert_raise(Fluent::ConfigError) do
          create_driver(test_conf)
        end
      end

      test 'try_count should be positive' do
        test_conf = generate_conf(extra_conf: ['try_count -1'])

        assert_raise(Fluent::ConfigError) do
          create_driver(test_conf)
        end
      end

      test 'try_delay should be positive' do
        test_conf = generate_conf(extra_conf: ['try_delay -1'])

        assert_raise(Fluent::ConfigError) do
          create_driver(test_conf)
        end
      end
    end

    sub_test_case 'queries' do
      test 'queries should not be empty' do
        test_conf = generate_conf(query_conf: [])

        assert_raise(Fluent::ConfigError) do
          create_driver(test_conf)
        end
      end
    end
  end

  sub_test_case 'run_queries' do
    test 'it call pg_client with expected query' do
      driver = create_driver
      input = driver.instance

      input.pg_client.expects(:query).with('select * from data').returns([])
      input.run_queries
    end

    test 'it emits returned events' do
      driver = create_driver
      input = driver.instance

      raw_records = [{ test1: 'test1' }, { test2: 'test2' }]
      input.pg_client.expects(:query).with('select * from data').returns(raw_records)

      input.run_queries
      emitted_events = driver.events

      emitted_events.each { |emitted_event| assert_equal input.tag, emitted_event[0] }
      emitted_records = emitted_events.map { |emitted_event| emitted_event[2] }
      assert_equal raw_records, emitted_records
    end

    test 'it emits events on specified tag' do
      test_query_conf = [
        '<query>',
        "sql #{SQL_QUERY}",
        'tag test',
        '</query>'
      ]

      test_conf = generate_conf(query_conf: test_query_conf)
      driver = create_driver(test_conf)
      input = driver.instance

      raw_records = [{ test3: 'test3' }]
      input.pg_client.expects(:query).with('select * from data').returns(raw_records)

      input.run_queries
      emitted_events = driver.events

      assert_equal 1, emitted_events.size
      assert_equal [input.tag, 'test'].join('.'), emitted_events.first.first

      emitted_records = emitted_events.map { |emitted_event| emitted_event[2] }
      assert_equal raw_records, emitted_records
    end
  end

  private

  def generate_conf(base_conf: BASE_CONF, extra_conf: [], query_conf: QUERY_CONF)
    (base_conf + extra_conf + query_conf).join("\n")
  end

  def create_driver(conf = generate_conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::PgQueryInput).configure(conf)
  end
end
