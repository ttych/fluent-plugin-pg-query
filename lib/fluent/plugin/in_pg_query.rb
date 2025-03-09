# frozen_string_literal: true

#
# Copyright 2025- Thomas Tych
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/plugin/input'

require_relative 'pg_query/pg_client'

module Fluent
  module Plugin
    class PgQueryInput < Fluent::Plugin::Input
      NAME = 'pg_query'

      Fluent::Plugin.register_input(NAME, self)

      helpers :event_emitter, :timer

      DEFAULT_TAG = NAME

      DEFAULT_INTERVAL = 300

      DEFAULT_PG_HOST = 'localhost'
      DEFAULT_PG_PORT = 5432
      DEFAULT_PG_USER = nil
      DEFAULT_PG_PASSWORD = nil
      DEFAULT_PG_SSLMODE = :allow
      DEFAULT_PG_CONNECT_TIMEOUT = 10
      DEFAULT_PG_TRY_COUNT = 3
      DEFAULT_PG_TRY_DELAY = 5

      DEFAULT_CA_CERT = nil

      DEFAULT_QUERY_TAG = nil

      desc 'tag to emit events on'
      config_param :tag, :string, default: DEFAULT_TAG

      desc 'interval for probe execution'
      config_param :interval, :time, default: DEFAULT_INTERVAL

      desc 'postgresql host'
      config_param :host, :string, default: DEFAULT_PG_HOST
      desc 'postgresql port'
      config_param :port, :integer, default: DEFAULT_PG_PORT
      desc 'postgresql database'
      config_param :database, :string
      desc 'postgresql user'
      config_param :user, :string, default: DEFAULT_PG_USER
      desc 'postgresql password'
      config_param :password, :string, default: DEFAULT_PG_PASSWORD
      desc 'postgresql ssl mode'
      config_param :sslmode, :enum, list: %i[disable allow prefer require verify-ca verify-full],
                                    default: DEFAULT_PG_SSLMODE
      desc 'postgresql connection timeout (in seconds)'
      config_param :connect_timeout, :integer, default: DEFAULT_PG_CONNECT_TIMEOUT
      desc 'postgresql try count, on error'
      config_param :try_count, :integer, default: DEFAULT_PG_TRY_COUNT
      desc 'postgresql try delay, between 2 tries, on error'
      config_param :try_delay, :integer, default: DEFAULT_PG_TRY_DELAY

      desc 'ca_cert'
      config_param :ca_cert, :string, default: DEFAULT_CA_CERT

      config_section :query, param_name: :queries, multi: true do
        config_param :sql, :string
        config_param :tag, :string, default: DEFAULT_QUERY_TAG
      end

      def configure(conf)
        super

        raise Fluent::ConfigError, 'tag should not be empty' if tag.empty?

        configure_pg_connection
        configure_pg_queries
      end

      def configure_pg_connection
        raise Fluent::ConfigError, 'port should be >= 0 and <= 65535' if port.negative? || port > 65_535
        raise Fluent::ConfigError, 'database should not empty' if database.empty?
        raise Fluent::ConfigError, 'connect_timeout should be >= 0' if connect_timeout.negative?
        raise Fluent::ConfigError, 'try_count should be >= 0' if try_count.negative?
        raise Fluent::ConfigError, 'try_delay should be >= 0' if try_delay.negative?
      end

      def configure_pg_queries
        raise Fluent::ConfigError, 'queries should not be empty' if queries.empty?
      end

      def start
        super

        timer_execute(:run_queries_first, 1, repeat: false, &method(:run_queries)) if interval > 60

        timer_execute(:run_queries, interval, repeat: true, &method(:run_queries))
      end

      def shutdown
        pg_client.close

        super
      end

      def run_queries
        queries.each do |query|
          run_query(query)
        rescue StandardError => e
          log.error "while runnig query: #{query.sql}: #{e}"
        end
        pg_client.standby
      end

      def run_query(query)
        query_time = Fluent::Engine.now
        records = pg_client.query(query.sql)
        emit_query_records(query_time: query_time, query_tag: query.tag, query_records: records)
      end

      def emit_query_records(query_records:, query_time: Fluent::Engine.now, query_tag: nil)
        current_tag = [tag, query_tag].compact.join('.')
        query_events = MultiEventStream.new
        query_records.each do |record|
          query_events.add(query_time, record)
        end
        router.emit_stream(current_tag, query_events)
      end

      def pg_client
        @pg_client ||= Fluent::Plugin::PgQuery::PgClient.from_conf(self)
      end
    end
  end
end
