# encoding: utf-8

# Copyright 2019 Micron Technology, Inc. <https://www.micron.com/>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This work contains copyrighted material, see NOTICE for
# additional copyright aknowledgements.

require 'logstash-output-azure_event_hub_jars'
require 'logstash/outputs/base'
require 'logstash/namespace'
require 'logstash/errors'


java_import com.microsoft.azure.eventhubs.ConnectionStringBuilder;
java_import com.microsoft.azure.eventhubs.EventData;
java_import com.microsoft.azure.eventhubs.EventHubClient;
java_import com.microsoft.azure.eventhubs.EventHubException;
java_import com.microsoft.azure.eventhubs.IllegalConnectionStringFormatException;

java_import java.io.IOException;
java_import java.nio.ByteBuffer;
java_import java.nio.charset.Charset;
java_import java.util.concurrent.ExecutionException;
java_import java.util.concurrent.Executors;
java_import java.util.concurrent.ScheduledExecutorService;

# Output plugin to send events to an Azure Event Hub.
class LogStash::Outputs::AzureEventHubs < LogStash::Outputs::Base
  config_name "azure_event_hub"

  # Azure Event Hub Connection String
  config :connection_string, :validate => :string, :required => true, :default => nil

  # Number of times to retry a failed Event Hubs connection
  # Defaults to 3
  config :connection_retry_count, :validate => :number, :required => false, :default => 3

  # Properties Bag
  # Event metadata key=value pairs to set in the user-defined property bag
  # See the EventData class for more information
  # https://docs.microsoft.com/en-us/java/api/com.microsoft.azure.eventhubs.eventdata?view=azure-java-stable
  # Format: properties_bag => { "key1" => "value1" "key2" => "%{[event_field]}" }
  config :properties_bag, :validate => :hash, :required => false, :default => nil

  # Total threads used by Azure Event Hubs client to handle events
  # Requires at minimum 2 threads
  # Defaults to 4
  config :client_threads, :validate => :number, :required => false, :default => 4

  # Default serialize messages with JSON
  default :codec, 'json'

  public
  def register

    # The Executor handles all the asynchronous tasks and this is passed to the EventHubClient.
    # The gives the user control to segregate their thread pool based on the work load.
    # This pool can then be shared across multiple EventHubClient instances.
    @executor_service = Executors.newScheduledThreadPool(@client_threads)

    # Handle Transient errors when creating the Event Hubs Client
    try = 0
    retry_interval = 2
    begin
      # Each EventHubClient instance spins up a new TCP/SSL connection, which is expensive.
      # It is always a best practice to reuse these instances.
      if !@connection_string.nil? and @connection_string !~ /\A\s*\Z/
        @eventhub_client = EventHubClient.createSync(@connection_string, @executor_service)
        @codec.on_event(&method(:send_record))
      else
        @logger.warn("Connection String is empty, azure_event_hub output will be ignored and should not be called...")
        @codec.on_event(&method(:log_no_msg_sent))
      end

    rescue IllegalConnectionStringFormatException, IOException => e
      @logger.error(
        "Unable to establish connection to Azure Event Hubs.",
        :error_message => e.getMessage(),
        :class => e.class.name
        )
      close()
      exit(1)
    rescue EventHubException, ExecutionException => e
      # Log error, no retry
      if (e.is_a?(EventHubException) and e.getIsTransient() != true) or try >= @connection_retry_count
        @logger.error(
          "Unable to establish connection to Azure Event Hubs.",
          :error_message => e.getMessage(),
          :class => e.class.name
          )
        close()
        exit(1)
      end

      # Log error with retry
      @logger.error(
        "Connection to Event Hubs failed, will attempt connection again.",
        :error_message => e.getMessage(),
        :class => e.class.name,
        :retry_in_seconds => retry_interval
      )

      # Wait for interval
      sleep(retry_interval)
      
      # Add attempt and retry
      try += 1
      retry
    end
  end # def register

  public
  def close
    if (!@eventhub_client.nil?)
      @eventhub_client.closeSync();
    end
    @executor_service.shutdown();
  end # def close
  
  public
  def receive(event)
    begin
      @codec.encode(event)
    rescue => e
      @logger.warn("Error encoding event", :exception => e, :event => event)
    end
  end # def receive

  private
  def send_record(event, payload)
    begin
      # Create EventData object and convert payload to bytes
      eh_event = EventData.create(ByteBuffer::wrap(payload.to_java_bytes))
      
      # Add property bag
      if (!@properties_bag.nil?)
        @properties_bag.each do |key, value|
          eh_event.getProperties().put(event.sprintf(key).to_java_string, event.sprintf(value).to_java_string)
        end
      end

      # Send using client
      @eventhub_client.sendSync(eh_event)
    rescue => e
      @logger.warn("Error sending event", :exception => e, :event => event)
    end
  end # def send_record

  private
  def log_no_msg_sent(event, payload)
    begin
      @logger.warn("Event ignored, connection string not set")
    end
  end # def log_no_msg_sent

end # class LogStash::Outputs::AzureEventHubs
