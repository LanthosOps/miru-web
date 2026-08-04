# frozen_string_literal: true

require "rails_helper"

RSpec.describe "internal deployment process entrypoints" do
  it "routes both production images through the startup gate" do
    expect(Rails.root.join("Dockerfile").read).to include('ENTRYPOINT ["/rails/bin/docker-entrypoint"]')
    expect(Rails.root.join("Dockerfile.production").read).to include('ENTRYPOINT ["/app/bin/docker-entrypoint"]')
  end

  it "routes Procfile web and worker processes through the startup gate" do
    procfile = Rails.root.join("Procfile").read

    expect(procfile).to include("web: bin/docker-entrypoint bundle exec falcon host")
    expect(procfile).to include("worker: bin/docker-entrypoint bundle exec rake solid_queue:start")
  end

  it "keeps the Render predeploy hook attached to the Lanthos fork" do
    blueprint = Rails.root.join("render.yaml").read

    expect(blueprint).to include("repo: https://github.com/LanthosOps/miru-web")
    expect(blueprint).to include("preDeployCommand: ./bin/render-predeploy")
    expect(blueprint).not_to include("repo: https://github.com/saeloun/miru-web")
  end
end
