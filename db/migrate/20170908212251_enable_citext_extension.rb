# frozen_string_literal: true

class EnableCitextExtension < ActiveRecord::Migration[5.0]
  def change
    enable_extension 'citext'
  end
end
