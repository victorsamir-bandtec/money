#!/bin/bash

# Script para adicionar arquivos ao projeto Xcode via linha de comando

echo "🔧 Adicionando arquivos ao projeto Money.xcodeproj..."

# Fechar Xcode se estiver aberto
osascript -e 'tell application "Xcode" to quit' 2>/dev/null

# Aguardar fechar
sleep 2

# Adicionar arquivos usando xcodebuild (não funciona diretamente, precisa de project.pbxproj edit)
# Alternativa: usar Ruby com xcodeproj gem

echo "📦 Instalando gem xcodeproj..."
gem install xcodeproj --user-install 2>/dev/null

echo "🔨 Executando script Ruby para adicionar arquivos..."

cat > /tmp/add_files.rb << 'RUBY'
require 'xcodeproj'

project_path = '/Users/victorsamir/Documents/Money/Money.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Encontrar o target Money
target = project.targets.find { |t| t.name == 'Money' }

if target.nil?
  puts "❌ Target 'Money' não encontrado!"
  exit 1
end

# Encontrar grupos
models_group = project.main_group.find_subpath('Money/Core/Models', true)
services_group = project.main_group.find_subpath('Money/Core/Services', true)
presentation_group = project.main_group.find_subpath('Money/Presentation', true)

# Adicionar AnalyticsModels.swift
analytics_models = models_group.new_file('AnalyticsModels.swift')
target.add_file_references([analytics_models])

# Adicionar HistoricalAggregator.swift
historical = services_group.new_file('HistoricalAggregator.swift')
target.add_file_references([historical])

# Adicionar CashFlowProjector.swift
projector = services_group.new_file('CashFlowProjector.swift')
target.add_file_references([projector])

# Adicionar pasta Analytics (recursivamente)
analytics_group = presentation_group.new_group('Analytics')

# Criar subgrupo Components
components_group = analytics_group.new_group('Components')

# Adicionar arquivos de Components
trend_chart = components_group.new_file('Components/TrendChart.swift')
scenario_card = components_group.new_file('Components/ScenarioCard.swift')
target.add_file_references([trend_chart, scenario_card])

# Adicionar arquivos raiz de Analytics
view_model = analytics_group.new_file('HistoricalAnalysisViewModel.swift')
scene = analytics_group.new_file('HistoricalAnalysisScene.swift')
target.add_file_references([view_model, scene])

# Salvar projeto
project.save

puts "✅ Arquivos adicionados com sucesso ao projeto Xcode!"
RUBY

# Executar script Ruby
ruby /tmp/add_files.rb

if [ $? -eq 0 ]; then
    echo "✅ Arquivos adicionados com sucesso!"
    echo "🔄 Reabrindo Xcode..."
    open /Users/victorsamir/Documents/Money/Money.xcodeproj
else
    echo "❌ Erro ao adicionar arquivos. Veja instruções manuais abaixo."
fi

# Limpar
rm -f /tmp/add_files.rb
