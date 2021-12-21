require 'travis/cli'

module Travis
  module CLI
    class Tam < ApiCommand
      description "TAM (Travis Artifact Manager) actions"

      on('-c', '--create-image IMAGE_NAME', 'Create image with given name')
      on('-u', '--update-image IMAGE_NAME', 'Update image with given name')
      on('-d', '--delete-image IMAGE_NAME', 'Delete image with given name')
      on('-i', '--image-info IMAGE_NAME', 'Get info for image with given name')

      def run
        error("Please specify an action") if !create_image? && !update_image? && !delete_image? && !image_info?
        authenticate

        image_action if create_image? || update_image? || delete_image?
        get_image_info if image_info?
      end

      def image_action
        error(".travis.lxd.yml file not found in the current directory or is empty") if (create_image? || update_image?) && (!File.exist?('.travis.lxd.yml') || File.read('.travis.lxd.yml').empty?)

        endpoint = if create_image?
                     'v3/artifacts/config/create'
                   elsif update_image?
                     'v3/artifacts/config/update'
                   else
                     "v3/artifacts/#{delete_image}"
                   end

        params = JSON.dump(
          image_name: create_image || update_image || delete_image,
          config: File.read('.travis.lxd.yml')
        )
        response = if create_image? || update_image?
                     session.post(endpoint, params, 'Content-Type' => 'application/json')
                   else
                     session.delete(endpoint)
                   end

        if create_image?
          say 'Image created'
        elsif update_image?
          say 'Image updated'
        else
          warn 'Image deleted'
        end
      end

      def get_image_info
        response = session.get_raw("v3/artifacts/#{image_info}/info")

        if response
          say color('Travis Artifacts image info:', :important)
          say color("Name: #{response['name']}\n", :info)
          say color("Description: #{response['description']}\n", :info)
          say color("Config content: #{response['config_content']}\n", :info)
          say color("Image size: #{response['image_size']}", :info)
        end
      end
    end
  end
end
