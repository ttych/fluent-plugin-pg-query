# frozen_string_literal: true

require 'pg'

module Fluent
  module Plugin
    module PgQuery
      class PgClient
        DEFAULT_TRY_COUNT = 3
        DEFAULT_TRY_DELAY = 5

        DEFAULT_HOST = 'localhost'
        DEFAULT_PORT = 5432
        DEFAULT_TIMEOUT = 10
        DEFAULT_SSLMODE = :allow

        attr_reader :try_count, :try_delay, :params, :logger

        def initialize(try_count: DEFAULT_TRY_COUNT, try_delay: DEFAULT_TRY_DELAY, logger: nil, **params)
          @try_count = try_count
          @try_delay = try_delay
          @logger = logger
          @params = params
        end

        def query(query_str)
          try_attempt ||= 0
          result = pg.exec(query_str)
          result.to_a
        rescue PG::Error => e
          try_attempt += 1
          if try_count && try_attempt < try_count
            logger&.warn("PG error on attempt #{try_attempt}/#{try_count}: #{e}")
            close
            sleep try_delay
            retry
          end
          logger&.error("PG error after #{try_count} attempts: #{e}")
          []
        end

        def standby
          close
        end

        def pg
          @pg ||= PG.connect(**pg_params)
        end

        def pg_params
          default_pg_params.merge(params.compact)
        end

        def default_pg_params
          {
            host: DEFAULT_HOST,
            port: DEFAULT_PORT,
            connect_timeout: DEFAULT_TIMEOUT,
            sslmode: DEFAULT_SSLMODE
          }
        end

        def close
          @pg&.close
        ensure
          @pg = nil
        end

        class << self
          def from_conf(conf)
            new(
              host: conf.host,
              port: conf.port,
              dbname: conf.database,
              connect_timeout: conf.connect_timeout,
              user: conf.user,
              password: conf.password,
              sslmode: conf.sslmode,
              sslrootcert: conf.ca_cert,
              try_count: conf.try_count,
              try_delay: conf.try_delay,
              logger: conf.log
            )
          end
        end
      end
    end
  end
end
