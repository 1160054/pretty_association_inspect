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
      route_arr  = route.map{|node| node.id}
      start_name = route_arr.pop.to_s.camelize
      route_arr.reverse!
      h = Hash.new
      h[route_arr.first] = {} if route_arr.count == 1
      h[route_arr.first] = route_arr.second if route_arr.count == 2
      h[route_arr.first] = {route_arr.second => route_arr.third} if route_arr.count == 3
      h[route_arr.first] = {route_arr.second => {route_arr.third => route_arr.fourth}} if route_arr.count == 4
      route_str = "#{start_name}.joins(#{h.to_s}).last." + route_arr.join(".").gsub("s.", "s.last.")
      ap route_str
      return route_str
    end

    def minimum_route(start_id, goal_id, max_cost)
      search_by_dikstra(start_id, goal_id, max_cost)
      passage = @nodes.find { |node| node.id == goal_id }
      route = [passage]
      while passage = @nodes.find { |node| node.id == passage.from }
        route << passage
      end
      route
    end

    def search_by_dikstra(start_id, goal_id, max_cost)
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
          next if reachble_node.nil?
          next if reachble_cost > max_cost
          if reachble_node.cost.nil? || reachble_cost < reachble_node.cost
            reachble_node.cost = reachble_cost
            reachble_node.from = next_node.id
          end
        end
      end
    end
  end

  def build_association_node(start, max_cost)
    models = ActiveRecord::Base.subclasses.map(&:name)
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
    route_hash = {}
    data.each do |goal, v|
      next if start == goal
      new_route = graph.print_route(graph.minimum_route(start, goal, max_cost))
      _model_ = ActiveRecord::Base.module_eval(goal.to_s.camelize.singularize).model_name.human rescue nil
      human_str = PrettyAssociationInspect.jp_scripe(_model_)
      route_hash["#{goal} #{human_str}"] = new_route if new_route
    end
    route_hash
  end


  # 『関連を可愛く表示するメソッド』を定義する
  def pretty_association_inspect_define(klass)
    klass.class_eval do |model|
      self.define_singleton_method(:to){
        associations_hash = PrettyAssociationInspect.build_association_hash(model)
        PrettyAssociationInspect.printed(klass, model, associations_hash)
        return self.first || self
      }

      define_method(:to){
        associations_hash = PrettyAssociationInspect.build_association_hash(model)
        PrettyAssociationInspect.printed(klass, model, associations_hash)
        return self
      }
      self.define_singleton_method(:toto){ |max_cost=1, start = nil|
        model_name_sym = model_name.singular.to_sym
        route_arr = PrettyAssociationInspect.build_association_node(start || model_name_sym, max_cost)
        ap route_arr.map { |route| [route.first, eval(route.last.to_s)] rescue nil }
        ap route_arr
        return nil
      }
      define_method(:toto){ |max_cost = 1, start = nil|
        model_name_sym = model_name.singular.to_sym
        route_arr = PrettyAssociationInspect.build_association_node(start || model_name_sym, max_cost)
        ap route_arr.map { |route| [route.first, eval(route.last.to_s)] rescue nil }
        ap route_arr
        return nil
      }
      self.define_singleton_method(:s){ |name = nil|
        results = Module.const_get(self.to_s).columns.select{|m| m.sql_type=~/char/}.map(&:name).map(&:to_sym).each_with_object([]) { |attr, records|
          result   = self.where(self.arel_table[attr].matches("%#{name}%"))
          records << [attr, result.ids, result]
        }.select{|m| m.second.present? }
        ap results
        result_where = self.where(id: results.map(&:second).flatten)
        ap result_where
        return result_where
      }
    end
  end

  # バリューを整形
  def value_convert(k, v, klass)
    klass.class_eval {
      return columns_hash[k.to_s].type if v.blank?
      is_e  = Object.const_defined?(:Enumerize) && first.send(k).kind_of?(Enumerize::Value)
      return "#{v} #{first.send(k).text} #{send(k).values} #{send(k).values.map(&:text)}" if is_e
      return v.strftime("%y年%m月%d日 %H:%M") if v.respond_to?(:strftime)
    }
  end

  # アソシエーションをハッシュに変換
  def build_association_hash(model)
    pretty_hash = model.reflect_on_all_associations.each_with_object({}) do |m, hash|
      name = m.class.to_s.gsub("ActiveRecord::Reflection::", "").gsub("Reflection", "").to_sym
      hash[name] ||= []
      human_name = PrettyAssociationInspect.jp_scripe(m.klass.model_name.human)
      hash[name] << [
        m.name, human_name
      ].compact.join(' | ')
      hash[name] = hash[name]
    end
  end

  # 表示
  def printed(klass, model, associations_hash)
    pretty_hash = {}
    begin
      klass.class_eval{|klass|
        klass.first.attributes.each{|k ,v|
          pretty_hash[k.to_sym] =
            [
              PrettyAssociationInspect.value_convert(k, v, klass),
              PrettyAssociationInspect.jp_scripe(klass.human_attribute_name(k)),
              v
            ].compact.join(' | ')
        }
      }
    rescue => e
      ap e
    end
    ap "-"*100;
    ap "#{klass.name} #{jp_scripe(klass.model_name.human)}"
    ap "[クラスメソッド]"
    base_pattern   = "(before|after|around)_(add|remove|restore)|_associated_records_for_|inherited"
    extr_pattern   = "attribute_type_decorations|soft_de|_restore_callback|indexed_|_by_resource"
    delete_pattern = Regexp.new( [ base_pattern, extr_pattern ].join('|') )
    class_m  = model.methods(false) - model.instance_methods
    ap (class_m).delete_if{|name|
      delete_pattern.match(name) }.sort
    ap "[インスタンスメソッド]"
    instance_m = model.instance_methods(false) - model.superclass.instance_methods
    ap (instance_m).delete_if{|name|
      delete_pattern.match(name) }.sort
    ap "[バリデーション]"
    puts model.validators.map{|m|
      m.class.name.gsub(/Active|Record|Validations|Model|Validator|::/,"")
        .concat(" #{m.attributes.join(', ')} #{m.options}") }.sort.uniq
    ap "[アソシエーション]"
    ap associations_hash
    ap "[詳細]"
    ap pretty_hash
    ap "-"*100
  end

  # 日本語だけ抽出
  def jp_scripe(str)
    japanese = Regexp.new(/[亜-熙ぁ-んァ-ヶ]/)
    str if japanese =~ str
  end

  # 全てのモデルにメソッドを定義する
  def all_models_define
    model_names_array = load_all_models
    model_names_array.each do |model_name|
      begin
        klass = eval(model_name)
        pretty_association_inspect_define(klass)
      rescue
        next
      end
    end
  end

  # 全てのモデルを読み込み、モデル名配列を返す
  def load_all_models
    #Dir.glob(Rails.root.join('app/models/*.rb')).each{|m| load m }
    models_file_path = Dir.glob(Rails.root.join("app/models/*")).grep(/rb\z/)
    models_file_path.each { |m| require(m) rescue next }
    return ActiveRecord::Base.subclasses.map(&:name).delete_if { |m| m=~/City/ }
  end

  def ap(*args)
    if Object.const_defined?("AwesomePrint")
      ap args
    else
      puts args
    end
  end

end
module Kernel
  extend self
  define_method(:ss) {|keyword = nil|
    ActiveRecord::Base.connection.tables.map(&:classify).map{|m| Object.const_get(m) rescue nil}.each_with_object({}){|m,h| h[m.try(:name).try(:to_sym)] = m.try(:column_names)}.compact.select{|_,v| v.any?{|m| keyword.nil? ? true : m.match(keyword) }}
  }
  define_method(:sss) {|keyword = nil|
    result = ActiveRecord::Base.connection.tables.map(&:classify).map{|m| Object.const_get(m) rescue nil}.each_with_object({}){|m,h| h[m.try(:name).try(:to_sym)] = m.try(:column_names)}.compact.select{|_,v| v.any?{|m| keyword.nil? ? true : m == keyword }}
    result.keys
  }
end
