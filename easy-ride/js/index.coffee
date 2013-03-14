rideSearcher = rideSearcher or {}
require [
    'components/map-route',
    'components/input/date-picker',
    'components/input/text-input'
    ], (MapRoute, DatePicker, TextInput) ->

    class RideSearcher
        constructor: ->
            # Google Maps Options
            @mapOptions =
                center: new google.maps.LatLng(51.517099, -0.146084)
                zoom: 12
                mapTypeId: google.maps.MapTypeId.ROADMAP

            # Initialize Google Maps
            @map = new google.maps.Map($('#map_canvas')[0], @mapOptions)

            # Member variables
            @womenOnly = $('#search-women-only')
            @departure = new DatePicker(
                $('#search-departure'),
                $('#search-departure-date'),
                false)

            @route = new MapRoute(
                $('#search-route'),
                @map,
                $('#search-from'),
                $('#search-to'))

            @searchButton = $('#search-button')
            
            @searchButton.click =>
                return null if @searchButton.hasClass('disabled')
                data = @toJson()
                return null if data == null
                console.log(data)

                @setButton('btn btn-primary disabled', 'Searching...')

                $.ajax
                    url: '/index_ajax.php'
                    type: 'GET'
                    data: 'data': JSON.stringify(data)
                    success: @searchResults
                    error: (data) ->
                        @setButton('btn btn-danger', 'Error!')

            @tripTemplate = _.template($('#trip-template').html())
            @trips = $('#trips')

            @requestModal = new RequestRideModal()

        searchResults: (data) =>
            console.log(data)
            error = 'Unknown Error!'
            json = JSON.parse(data)
            if json
                if json['status'] == 'OK'
                    @clearTrips()
                    if json['trips'].length == 0
                        @setButton('btn btn-primary', 'No trips found')
                    else
                        @processResults(json['trips'])
                        @setButton('btn btn-primary', 'Search')
                    return
                else
                    error = json['msg']
            @setButton('btn btn-danger', error)

        clearTrips: =>
            @trips.html('')
            
        setButton: (btnClass, msg) =>
            @searchButton.attr('class', btnClass)
            @searchButton.html("<i class='icon icon-white icon-search'></i> #{msg}")

        toJson: =>
            json =
                departure: @departure.getTime()
                women_only: @womenOnly.prop('checked')
                route: @route.toJson()
            if json['route'] == null or json['women_only'] == null
                return null
            return json

        processResults: (trips) =>
            @tripsTable = {}
            @trips.hide()
            for trip in trips
                id = trip['id']
                trip.departure_string = (new Date(parseInt(trip.departure_time) * 1000)).toLocaleString()
                routeRenderer = new RouteRenderer(@map, trip)
                tripHTML = @tripTemplate(trip)
                @trips.append(tripHTML)
                $("#trip-#{id}").hover(routeRenderer.hoverIn, routeRenderer.hoverOut)
                $("#request-trip-#{id}").click(@requestRide)
                @tripsTable[id] = trip
            @trips.slideDown(1000)

        requestRide: (e) =>
            tripId = parseInt(e.target.id.split('-')[2])
            button = $("##{e.target.id}")
            return if button.hasClass('disabled')
            if $('#logged-in').length == 0     # If not logged in
                button.attr('class', 'btn btn-danger btn-small')
                button.text('Login Required!')
                return
            @requestModal.reset()
            console.log("TripID: #{tripId}")
            console.log(@tripsTable[tripId])
            @requestModal.load(@tripsTable[tripId])
            @requestModal.show()


    class RouteRenderer
        constructor: (@map, @route) ->
            @mapRendererOptions =
                markerOptions:
                    visible: false
                polylineOptions:
                    strokeOpacity: 0.0
                    strokeWeight: 4
            @directionsDisplay = new google.maps.DirectionsRenderer(@mapRendererOptions)
            @directionsDisplay.setMap(@map)

            request =
                origin: route['origin']['address']
                destination: route['destination']['address']
                travelMode: google.maps.TravelMode.DRIVING
                region: 'uk'

            @directionsService = new google.maps.DirectionsService()
            @directionsService.route request, (result, status) =>
                if status == google.maps.DirectionsStatus.OK
                    @directionsDisplay.setDirections(result)

        hoverIn: (e) =>
            @mapRendererOptions.polylineOptions.strokeOpacity = 0.8
            @directionsDisplay.setMap(@map)

        hoverOut: (e) =>
            @mapRendererOptions.polylineOptions.strokeOpacity = 0.0
            @directionsDisplay.setMap(@map)

    class RequestRideModal
        constructor: () ->
            @el = $('#modal-request-ride')
            @info = $('#modal-trip-info')
            @requestMessage = new TextInput(
                $('#modal-trip-request-message').parent().parent(),
                $('#modal-trip-request-message'))
            @submitButton = $('#modal-request-ride-submit')
            @submitButton.click(@submit)
            @tripTemplate = _.template($('#trip-modal-template').html())
        
        load: (trip) =>
            @tripId = trip['id']
            console.log(trip)
            @info.append(@tripTemplate(trip))

        show: =>
            @el.modal('show')

        hide: =>
            @el.modal('hide')

        reset: =>
            @info.html('')
            @setButton('btn btn-primary', 'Request')

        toJson: =>
            'message': @requestMessage.getValue()
            'trip_id': @tripId

        submit: (e) =>
            console.log(@toJson())
            data = @toJson()
            $.ajax
                url: '/index_ajax.php'
                type: 'POST'
                data: 'data': JSON.stringify(data)
                success: (data) =>
                    console.log(data)
                    json = JSON.parse(data)

                    if not json
                        @setButton('btn btn-danger', 'Unknown error!')
                        return

                    if json['status'] == 'OK'
                        @hide()
                        @reset()
                        $("#request-trip-#{@tripId}").attr('class', 'btn btn-info btn-small disabled')
                        $("#request-trip-#{@tripId}").html('<i class="icon icon-envelope icon-white"></i> Ride Requested')
                        console.log($("#request-trip-#{@tripId}"))
                    else 
                        @setButton('btn btn-danger', json['msg'])

                error: (data) ->
                    @setButton('btn btn-danger', 'Unknown error!')

        setButton: (btnClass, msg) =>
            @submitButton.attr('class', btnClass)
            @submitButton.html("<i class='icon icon-white icon-search'></i> #{msg}")


    rideSearcher = new RideSearcher()