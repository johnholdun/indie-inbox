class Schema
  def self.load!
    DB.create_table?(:actors) do
      column :id, :string, unique: true
      column :type, :string
      column :private_key, :string
      column :fetched_at, :time
      column :json, :json
    end

    DB.create_table?(:activities) do
      column :id, :string, unique: true
      column :type, :string
      column :actor, :string
      column :object, :string
      column :target, :string
      column :published, :time
      column :json, :json
    end

    DB.create_table?(:objects) do
      column :id, :string, unique: true
      column :type, :string
      column :published, :time
      column :json, :json
    end

    DB.create_table?(:inbox) do
      primary_key :id
      column :actor, :string
      column :activity, :string
    end

    DB.create_table?(:follows) do
      column :actor, :string
      column :object, :string
      column :accepted, :boolean
    end
  end
end
