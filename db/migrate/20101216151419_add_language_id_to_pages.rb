class AddLanguageIdToPages < ActiveRecord::Migration
  def self.up
    add_column :pages, :language_id, :integer
    rename_column :pages, :language, :language_code
    rename_column :pages, :language_root_for, :language_root
    change_column :pages, :language_root, :boolean
    add_index :pages, :language_id
    Page.reset_column_information
    Page.all.each do |page|
      page.language = Language.find_by_code(page.language_code)
      page.language_root = !page.language_root.nil?
      page.save(false)
    end
  end

  def self.down
    remove_index :pages, :language_id
    change_column :pages, :language_root, :string
    rename_column :pages, :language_root, :language_root_for
    rename_column :pages, :language_code
    remove_column :pages, :language_id
  end
end