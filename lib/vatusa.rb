# frozen_string_literal: true

require 'httparty'
require 'ostruct'

# VATUSA API
#
# Initialization: api = VATUSA::API.new('https://api.vatusa.net', 'KEY')
#
module VATUSA
  # rubocop:disable Metrics/ClassLength
  class API
    include HTTParty

    attr_reader :url, :key, :base_url

    # Initialize new API object for manipulating the VATUSA API
    #
    # Arguments:
    #   url:  String containing URL for the
    #         API (Example: 'https://api.vatusa.net')
    #   key:  String containing API KEY (Example: 'abcd123')
    #
    def initialize(url, key)
      @url = url
      @key = key
      @base_url = "#{@url}/#{@key}"
    end

    # Retrieve all available CBT blocks associated with your API key
    #
    # Returns Array of OpenStruct objects with the following methods:
    #   id:       CBT Block ID (Example: '195')
    #   order:    Ordering sequence of the CBT (Example: '1')
    #   name:     Name of the CBT block (Example: 'Test CBT Block')
    #   visible: '1' (Visible) or '0' (Hidden)
    #
    def cbt_blocks
      response = self.class.get(@base_url + '/cbt/block')
      check_response(response)['blocks'].collect { |b| OpenStruct.new(b) }
    end # def cbt_blocks

    # Get all chapters associated with a CBT block, block must be
    # associated with your API key
    #
    # Returns OpenStruct object with the following methods:
    #   id:       CBT Block ID (Example: '195')
    #   name:     The name of the CBT Block (Example: 'Test CBT Block')
    #   chapters: Array of OpenStruct objects representing chapters
    #             with methods:
    #             id:     Chapter ID (Example: '12')
    #             order:  Ordering sequence of the chapter (Example: '1')
    #             name:   Name of the chapter (Example: 'Test CBT Chapter')
    #             url:    URL to chapter content (Example: 'http://example.com')
    #
    def cbt_block(block_id)
      response = self.class.get(@base_url + '/cbt/block/' + block_id.to_s)
      response = check_response(response)

      id       = response.delete 'blockId'
      name     = response.delete 'blockName'
      chapters = response.delete('chapters').collect { |c| OpenStruct.new(c) }

      OpenStruct.new(id: id, name: name, chapters: chapters)
    end # def cbt_block

    # Get chapter information. Associated block must be associated
    # with your API key.
    #
    # Returns OpenStruct object with the following methods:
    #   id:      CBT Chapter ID (Example: '12')
    #   blockId: CBT Block ID (Example: '195')
    #   order:   Ordering sequence of the chapter (Example: '1')
    #   name:    Name of the chapter (Example: 'Test CBT Chapter')
    #   url:     URL to chapter content
    #
    def cbt_chapter(chapter_id)
      response = self.class.get(@base_url + '/cbt/chapter/' + chapter_id.to_s)
      response = check_response(response)

      OpenStruct.new(response['chapter'])
    end

    # Add CBT chapter completion.
    #
    # Arguments:
    #   cid:        VATSIM ID of student (Example: 1300001)
    #   chapter_id: Completed chapter ID (Example: 12)
    #
    # Returns true if successful. Otherwise Raises exception.
    #
    def cbt_progress(cid, chapter_id)
      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }

      body = { chapterId: chapter_id.to_s }

      response = self.class.put(
        @base_url + '/cbt/progress/' + cid.to_s,
        query: body,
        headers: headers
      )

      check_response(response)
      true
    end

    # Get information for a controller
    #
    # Returns OpenStruct object of response with the following methods:
    #   fname:          First name
    #   lname:          Last name
    #   facility:       ICAO of member facility
    #   rating:         Rating expressed as integer
    #   join_date:      Time of date joined VATUSA
    #   last_activity:  Time of last activity on VATUSA
    #
    def controller(cid)
      response = self.class.get(@base_url + '/controller/' + cid.to_s)
      response = check_response(response)

      controller = response.to_h
      # Clean up response hash
      controller.delete 'status' # purge the response status form the hash
      controller['rating'] = controller['rating'].to_i

      controller['join_date'] = Time.parse(controller['join_date'] + ' UTC').utc

      controller['last_activity'] = Time.parse(
        controller['last_activity'] + ' UTC'
      ).utc

      OpenStruct.new(controller)
    end

    # Request exam results for a CID, this will return all completed exams.
    #
    # Returns Array of OpenStruct objects for each completed exam with the
    # following methods:
    #   id:     Exam ID (Example: '18307')
    #   name:   Name of the exam (Example: 'VATUSA -  Basic ATC Quiz')
    #   score:  Result score (Example: '88')
    #   passed: Boolean whether test resulted in a pass or fail (Example: true)
    #   date:   Time object representing the date of the exam
    #
    def exam_results(cid)
      response = self.class.get(@base_url + '/exam/results/' + cid.to_s)
      response = check_response(response)

      if response['cid'] == cid.to_s
        results = []

        response['exams'].each do |exam|
          exam['date'] = Time.parse(exam['date'] + ' UTC').utc
          results.push OpenStruct.new(exam)
        end

        results
      else
        e = "VATSIM API returned incorrect exam result set for: #{cid}"
        raise ResponseError, e
      end
    end

    # Request a specific exam result by result ID
    #
    # Returns OpenStruct Object with the following methods:
    #   id:     Exam result ID (Example: '18307')
    #   cid:    VATSIM ID of test taker (Example: '1300006')
    #   name:   Name of exam (Example: 'VATUSA - Basic ATC Quiz')
    #   score:  Result score (Example: '84')
    #   passed: Boolean whether test resulted in a pass or fail (Example: true)
    #   date:   Time object representing the date of the exam
    #
    #   Note: Questions may not be available if there was not any data
    #         available. Results from the old site did not contain convertible
    #         data, so individual exam results data will not be available
    #         and "questions" will not be defined at all.
    #   questions: Array containing objects with the following methods:
    #     question:   String containing question text
    #     correct:    String containing the correct answer
    #     selected:   String containing the answer the student selected
    #     is_correct: Boolean whether the question was correct or incorrect
    #
    def exam_result(result_id)
      response = self.class.get(@base_url + '/exam/result/' + result_id.to_s)
      response = check_response(response)

      # Fix consistency issues with passed attribute returning
      # true/false in exam_results versus returning 0 or 1 here.
      response['passed'] = !response['passed'].to_i.zero?
      response['date']   = Time.parse(response['date'] + ' UTC').utc

      # Convert questions to OpenStruct objects (if questions exist)
      if response.key? 'questions'
        response['questions'] = response.delete('questions').collect do |q|
          OpenStruct.new(q)
        end
      end

      OpenStruct.new(response)
    end

    # Retrieve the roster associated with your API key
    #
    # Returns OpenStruct object with the following methods:
    #   id:     String representing ARTCC ICAO
    #   url:    String containing URL for ARTCC
    #   name:   String containing name of ARTCC
    #   atm:    VATSIM CID of Air Traffic Manager or nil if not assigned
    #   datm:   VATSIM CID of Deputy Air Traffic Manager or nil if not assigned
    #   ta:     VATSIM CID of Training Administrator or nil if not assigned
    #   ec:     VATSIM CID of Events Coordinator or nil if not assigned
    #   wm:     VATSIM CID of Web Master or nil if not assigned
    #   fe:     VATSIM CID of Facility Engineer or nil if not assigned
    #
    #   members:  Array of OpenStruct objects containing members of the ARTCC
    #             with the following methods:
    #             cid: VATSIM CID
    #             fname: String containing first name
    #             lname: String containing last name
    #             email: String containing email
    #             rating: Integer representation of member rating
    #
    def roster
      response = self.class.get(@base_url + '/roster')
      response = check_response(response)

      response.delete 'status'
      response['facility'] = process_roster_facility(response['facility'])

      OpenStruct.new(response['facility'])
    end

    # Remove the CID from the facility associated with the API key
    #
    # Arguments:
    #   cid:        VATSIM ID of member to delete
    #   staff_cid:  VATSIM ID of staff member making deletion
    #   message:    String containing reason for deletion
    #
    # Returns true if successful. Otherwise Raises exception.
    #
    def roster_delete(cid, staff_cid, message)
      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }

      body = { by: staff_cid.to_s, msg: message.to_s }

      response = self.class.delete(
        @base_url + '/roster/' + cid.to_s,
        query: body,
        headers: headers
      )

      check_response(response)
      true
    end

    # Retrieve the pending transfers associated with your API key
    #
    # Returns an Array of OpenStruct objects for pending inbound transfers
    # with the following methods:
    #   id:             Integer containing Transfer request ID (Example: '14')
    #   cid:            Integer containing VATSIM ID of member requesting
    #                   transfer (Example: 1300001)
    #   fname:          String containing first name of member
    #   lname:          String containing last name of member
    #   rating:         Integer representation of rating (Example: 1)
    #   email:          String containing member email address
    #   from_facility:  String containing ICAO of origin ARTCC
    #   reason:         String containing reason for transfer request
    #   submitted:      Date of transfer request
    #
    def transfers
      response = self.class.get(@base_url + '/transfer')
      response = check_response(response)

      response['transfers'].collect { |t| process_transfer_entry(t) }
    end

    # Process a transfer request
    #
    # Arguments:
    #   transfer_request_id: Integer of transfer request (found from #transfers)
    #   staff_cid:           Integer containing VATSIM ID of staff
    #                        approving request
    #   action:              Symbol: Either :accept or :reject
    #   reason:              String containing reason (required
    #                        if action :reject)
    #
    # rubocop:disable Metrics/MethodLength
    def transfer(transfer_request_id, staff_cid, action, reason = nil)
      if action == :reject && reason.to_s.blank?
        raise ArgumentError, 'Reason required'
      end

      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }

      url = @base_url + '/transfer/' + transfer_request_id.to_s

      case action
      when :accept
        body = { action: action.to_s, by: staff_cid.to_s }
      when :reject
        body = { action: action.to_s, by: staff_cid.to_s, reason: reason.to_s }
      else
        raise ArgumentError, "Unknown action: '#{action}'"
      end

      response = self.class.post(url, query: body, headers: headers)
      check_response(response)
      true
    end
    # rubocop:enable Metrics/MethodLength

    private

    # Checks for a 200 OK response and returns the response object.
    # Otherwise raises a ResponseError exception.
    #
    def check_response(response)
      unless response.code == 200
        raise ResponseError, "Response returned status code #{response.code}"
      end

      response
    end

    # Process the facility subsection response from '/roster'
    #
    def process_roster_facility(facility)
      %w[atm datm ta ec wm fe].each do |s|
        facility[s] = facility[s].to_i
        facility[s] = nil if facility[s].zero?
      end

      facility['roster'].collect! { |c| process_roster_member(c) }
      # rename the roster key to members
      facility['members'] = facility.delete 'roster'
      facility
    end

    # Process an entry of the roster
    #
    def process_roster_member(member)
      member['cid']    = member['cid'].to_i
      member['rating'] = member['rating'].to_i
      OpenStruct.new(member)
    end

    # Process an entry of the transfer request list
    #
    def process_transfer_entry(entry)
      entry['id']         = entry['id'].to_i
      entry['cid']        = entry['cid'].to_i
      entry['rating']     = entry['rating'].to_i
      entry['submitted']  = Date.parse(entry['submitted'])
      OpenStruct.new(entry)
    end

    class ResponseError < StandardError; end
  end # class API
end # module VATSIM
