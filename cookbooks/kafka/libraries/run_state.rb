module KafkaRunStateHelpers
  def kafka_brokers(cluster_name = node.cluster_name, fallback = nil)
    k = node.nodes.cluster(cluster_name).role("kafka")
    k = node.nodes.cluster(fallback).role("kafka") if fallback && k.empty?
  end

  def kafka_connect(cluster_name = node.cluster_name, fallback = nil)
    kafka_brokers(cluster_name, fallback).map do |broker|
      "#{broker[:ipaddress]}:9092"
    end.join(',')
  end
end

include KafkaRunStateHelpers

class Chef
  class Recipe
    include KafkaRunStateHelpers
  end

  class Node
    include KafkaRunStateHelpers
  end

  class Resource
    include KafkaRunStateHelpers
  end
end
