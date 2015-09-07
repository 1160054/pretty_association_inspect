# -*- coding: utf-8 -*-
# モデルに関連情報を見やすく表示するメソッドを定義します。
module PrettyAssociationInspect
  extend self

  class Edge
    def initialize(cost, node_id)
      @cost, @node_id = cost, node_id
    end
    attr_reader :cost, :node_id
  end

  class Node
    def initialize(id, edges, cost=nil, done=false, from=nil)
      @id, @edges, @cost, @done, @from = id, edges, cost, done, from
    end
    attr_accessor :id, :edges, :cost, :done, :from
  end

  class Graph
    def initialize(data)
      @nodes = data.map do |node_id, edges|
        edges.map!{|edge| Edge.new(*edge)}
        Node.new(node_id, edges)
      end
    end

    def print_route(route)
      return false if route[0].cost.nil?
      route_arr = route.map{|node| node.id}
      start_name = route_arr.pop.to_s.singularize.capitalize
      ap "#{start_name}.first." + route_arr.reverse.join(".").gsub("s.", "s.first.")
    end

    def minimum_route(start_id, goal_id)
      search_by_dikstra(start_id, goal_id)
      passage = @nodes.find { |node| node.id == goal_id }
      route = [passage]
      while passage = @nodes.find { |node| node.id == passage.from }
        route << passage
      end
      route
    end

    def search_by_dikstra(start_id, goal_id)
      @nodes.each do |node|
        node.cost = node.id == start_id ? 0 : nil
        node.done = false
        node.from = nil
      end
      loop do
        next_node = nil
        @nodes.each do |node|
          next if node.done || node.cost.nil?
          next_node = node if next_node.nil? || node.cost < next_node.cost
        end
        break if next_node.nil?
        next_node.done = true
        next_node.edges.each do |edge|
          reachble_node = @nodes.find { |node| node.id == edge.node_id }
          reachble_cost = next_node.cost + edge.cost
          if reachble_node.cost.nil? || reachble_cost < reachble_node.cost
            reachble_node.cost = reachble_cost
            reachble_node.from = next_node.id
          end
        end
      end
    end
  end

  def build_association_node(start)
    models = load_all_models

    data = models.each_with_object({}) do |model_name_str, hash|
      eval(model_name_str).reflect_on_all_associations.each do |m|
        model_single_name   = eval(model_name_str).model_name.singular.to_sym
        model_multiple_name = eval(model_name_str).model_name.plural.to_sym
        hash[model_single_name]   ||= []
        hash[model_multiple_name] ||= []
        hash[model_single_name]   << [1, m.name]
        hash[model_multiple_name] << [1, m.name]
      end
    end
    graph = Graph.new(data)
    data.each do |goal, v|
      next if start == goal
      graph.print_route(graph.minimum_route(start, goal))
    end
    nil
  end


  # 『関連を可愛く表示するメソッド』を定義する
  def pretty_association_inspect_define(klass)
    klass.class_eval do |model|
      self.define_singleton_method(:to){ |start = nil|
        associations_hash = PrettyAssociationInspect.build_association_hash(model)
        PrettyAssociationInspect.printed(klass, model, associations_hash)
        model_name_sym = model_name.singular.to_sym
        PrettyAssociationInspect.build_association_node start || model_name_sym

        return self.last || self
      }

      define_method(:to){ |start = nil|
        associations_hash = PrettyAssociationInspect.build_association_hash(model)
        PrettyAssociationInspect.printed(klass, model, associations_hash)
        model_name_sym = model_name.singular.to_sym
        PrettyAssociationInspect.build_association_node start || model_name_sym
        return self
      }
    end
  end

  # アソシエーションをハッシュに変換
  def build_association_hash(model)
    model.reflect_on_all_associations.each_with_object({}) do |m, hash|
      name = m.class.class_name.gsub("Reflection", "")
      hash[name] ||= []
      human_name = PrettyAssociationInspect.jp_scripe(m.klass.model_name.human)
      hash[name] << {
        association: m.name,
        human: human_name,
        model_name: m.active_record.name
      }
    end
  end

  # バリューを整形
  def value_convert(k, v, klass)
    klass.class_eval {
      is_e  = Object.const_defined?(:Enumerize) && first.send(k).kind_of?(Enumerize::Value)
      return "#{v} #{first.send(k).text} #{send(k).values} #{send(k).values.map(&:text)}" if is_e
      return v.strftime("%y年%m月%d日 %H:%M") if v.respond_to?(:strftime)
      return columns_hash[k.to_s].type if v.blank?
    }
  end

  # 表示
  def printed(klass, model, associations_hash)
    pretty_associations_array = []
    klass.class_eval{|klass|
      klass.first.attributes.each{|k ,v|
        column = "%20s" % k
        value  = PrettyAssociationInspect.value_convert(k, v, klass)
        jp_val = PrettyAssociationInspect.jp_scripe(klass.human_attribute_name(k))
        db_val = "%5s"  % v
        pretty_associations_array <<  "#{column} #{jp_val} #{db_val}"
      }
    }
    ap "-"*100;
    ap klass.name + "#{jp_scripe(klass.model_name.human)}"
    ap "[クラスメソッド]"
    base_pattern   = "(before|after|around)_(add|remove|restore)|_associated_records_for_|inherited"
    extr_pattern   = "attribute_type_decorations|soft_de|_restore_callback|indexed_|_by_resource"
    delete_pattern = Regexp.new( [ base_pattern, extr_pattern ].join('|') )
    class_m  = model.methods(false) - model.instance_methods
    ap (class_m).delete_if{|name|
      delete_pattern.match(name) }.sort.join(', ')
    ap "[インスタンスメソッド]"
    instance_m = model.instance_methods(false) - model.superclass.instance_methods
    ap (instance_m).delete_if{|name|
      delete_pattern.match(name) }.sort.join(', ')
    ap "[バリデーション]"
    puts model.validators.map{|m|
      m.class.name.gsub(/Active|Record|Validations|Model|Validator/,"")
        .concat(": #{m.attributes.join(', ')} #{m.options}") }.sort.uniq
    ap "[アソシエーション]"
    associations_hash.each do |k, v|
      puts "%10s"%k + "  " + v.map{ |m| [m[:association], m[:human]].join }.join(', ')
    end
    ap "[詳細]"
    ap pretty_associations_array
    ap "-"*100
  end

  # 日本語だけ抽出
  def jp_scripe(str)
    japanese = Regexp.new(/[亜-熙ぁ-んァ-ヶ]/)
    "(#{str})" if japanese =~ str
  end

  # 全てのモデルにメソッドを定義する
  def all_models_define
    model_names_array = load_all_models
    model_names_array.each do |model_name|
      klass = eval(model_name)
      pretty_association_inspect_define(klass)
    end
  end

  # 全てのモデルを読み込み、モデル名配列を返す
  def load_all_models
    models_file_path = Dir.glob(Rails.root.join("app/models/*")).grep(/rb\z/)
    models_file_path.each { |m| load(m) }
    return ActiveRecord::Base.subclasses.map(&:name)
  end

end

module Kernel
  extend self

  if defined?(Pry)
    def to( obj = self )
      binding.pry obj
    end
  end

  def a
    load '/home/developer/pretty_association_inspect/lib/pretty_association_inspect.rb'
    files_path = Dir.glob(Rails.root.join("app/**/*")).grep(/\.rb\z/)
    files_path.each { |m| load(m) }

    [
     PrettyAssociationInspect.all_models_define,
     ApplicationController.subclasses.each_with_object({}){|m, h|
       h[m.name.to_sym] = m.action_methods.to_a.join(', ')
     }
     ]
  end
end
