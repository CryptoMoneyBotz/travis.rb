require 'travis/cli'
require 'travis/tools/safe_string'
require 'travis/tools/system'

module Travis
  module CLI
    class Tam < ApiCommand
      include Tools::SafeString

      description "TAM (Travis Artifact Manager) actions"

      on('-c', '--create-image IMAGE_NAME', 'Create image with given name')
      on('-u', '--update-image IMAGE_NAME', 'Update image with given name')
      on('-d', '--delete-image IMAGE_NAME', 'Delete image with given name')
      on('-i', '--image-info IMAGE_NAME', 'Get info for image with given name')
      on('-l', '--image-logs IMAGE_NAME', 'Get logs for image with given name')
      on('-s', '--image-build-status IMAGE_NAME', 'Get build status for image with given name')

      def run
        error("Please specify an action") if !create_image? && !update_image? && !delete_image? && !image_info? && !image_logs? && !image_build_status?
        authenticate

        image_action if create_image? || update_image? || delete_image?
        get_image_info(image_info) if image_info?
        display_image_log(image_logs) if image_logs?
        get_image_build_status(image_build_status) if image_build_status?
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
        begin
          response = if create_image? || update_image?
                       session.post_raw(endpoint, params, 'Content-Type' => 'application/json')
                     else
                       session.delete(endpoint)
                     end
        rescue Travis::Client::ValidationFailed => e
          error e.message
        end

        if create_image? || update_image?
          say create_image? ? 'Image created' : 'Image updated'

          unless response['warnings'].nil?
            warn color('Additionally following warnings were generated:', [:bold, 'yellow'])
            response['warnings'].each { |warning| warn color(warning, 'yellow') }
          end
        else
          warn 'Image deleted'
        end
      end

      def get_image_info(image_name)
        response = session.get_raw("v3/artifacts/#{image_name}/info")

        if response
          say color('Travis Artifacts image info:', :important)
          say color("Name: #{response['name']}\n", :info)
          say color("Description: #{response['description']}\n", :info)
          say color("Config content:\n#{response['config_content']}\n", :info)
          say color("Image size: #{response['image_size']}", :info)
        end
      end

      def display_image_log(image_name)
        info "displaying logs for image #{color(image_name, [:bold, :info])}"

        log = session.get_raw("v3/artifacts/#{image_name}/logs")['log']
        print_log(log)
      end

      def print_log(part)
        print interactive? ? encoded(part) : clean(part)
      end

      def get_image_build_status(image_name)
        response = session.get_raw("v3/artifacts/#{image_name}/build_status")

        if response
          say color('Travis Artifacts image build status:', :important)
          say color(response['status'], [state_color(response['status']), :bold])
        end
      end

      def state_color(state)
        case state
        when 'created', 'queued', 'received', 'started' then 'yellow'
        when 'passed', 'ready'                then 'green'
        when 'errored', 'canceled', 'failed'  then 'red'
        end
      end
    end
  end
end
