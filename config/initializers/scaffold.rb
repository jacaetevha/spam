require 'scaffolding_extensions'
ScaffoldingExtensions.auto_complete_skip_style = true
ScaffoldingExtensions.javascript_library = 'JQuery'
Sequel::Model::SCAFFOLD_OPTIONS[:text_to_string] = true
Sequel::Model::SCAFFOLD_OPTIONS[:association_list_class] = 'scaffold_associations_tree'
Sequel::Model::SCAFFOLD_OPTIONS[:auto_complete].merge!(:sql_name=>'name', :search_operator=>'ILIKE', :results_limit=>15, :phrase_modifier=>:to_s)
