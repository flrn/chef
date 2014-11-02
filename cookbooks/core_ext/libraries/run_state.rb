module RunStateHelpers
  def roles
    node.run_state[:roles]
  end

  def users
    node.run_state[:users]
  end

  def nodes
    @nodes ||= Nodes.new(node)
  end
end

class Nodes
  include Enumerable

  attr_reader :node
  attr_accessor :nodes

  def initialize(node)
    @node = node
    nodes = node.run_state[:nodes]
    # make sure we use attributes from current node instead of stale data from
    # the search index to prevent chicken-egg problems
    nodes.delete_if { |n| n[:fqdn] == node[:fqdn] }
    nodes << node
    @nodes = nodes.sort_by { |n| n[:fqdn] }
  end

  def each(&block)
    @nodes.each(&block)
  end

  def length
    @nodes.length
  end

  def empty?
    @nodes.empty?
  end

  def filter(&block)
    dup.tap do |obj|
      obj.nodes = @nodes.select(&block)
    end
  end

  def cluster(*names)
    filter do |n|
      names.include?(n.cluster_name) rescue false
    end
  end

  def environment(*names)
    filter do |n|
      names.include?(n.chef_environment) rescue false
    end
  end

  def role(*names)
    filter do |n|
      names.map { |name| n.role?(name) }.any?
    end
  end
end

class Chef
  class Node
    include RunStateHelpers
  end
end
