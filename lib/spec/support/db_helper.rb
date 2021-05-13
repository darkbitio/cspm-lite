require 'redisgraph'

def graphdb
  db_config = { url: 'redis://redis:6379' }
  db ||= RedisGraph.new('opencspm', db_config)
end
