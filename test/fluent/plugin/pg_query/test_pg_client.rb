# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/pg_query/pg_client'

class PgClientTest < Test::Unit::TestCase
  def setup
    @pg_client = Fluent::Plugin::PgQuery::PgClient.new
  end

  sub_test_case 'configuration' do
    test 'default try settings' do
      assert_equal 3, @pg_client.try_count
      assert_equal 5, @pg_client.try_delay
    end
  end

  sub_test_case 'quer' do
    test 'it uses a pg instance' do
      mocked_pg = mock('PG::Connection')
      mocked_pg.stubs(:type_map_for_results=)

      PG.expects(:connect).once.returns(mocked_pg)
      PG::BasicTypeMapForResults.stubs(:new)

      mocked_pg.expects(:exec).with('test').returns([])

      assert @pg_client.query('test')
    end

    test 'it returns what is returned by pg instance' do
      mocked_pg = mock('PG::Connection')
      mocked_pg.expects(:type_map_for_results=)

      PG.expects(:connect).once.returns(mocked_pg)
      PG::BasicTypeMapForResults.stubs(:new)

      mocked_pg.expects(:exec).once.with('test').returns([{ test: 'test' }])

      data = @pg_client.query('test')
      assert_equal [{ test: 'test' }], data
    end
  end
end
