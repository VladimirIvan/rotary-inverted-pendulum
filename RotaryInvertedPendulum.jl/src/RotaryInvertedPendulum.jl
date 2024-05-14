module RotaryInvertedPendulum

using Dates
using Joysticks
using LibSerialPort
using Plots

# Constants
const BAUD_RATE = 115200  # Baud rate for the serial communication
CONTROL_FREQUENCY = 100  # Frequency of the control loop (in Hz)

# Command constants
const CHECK_READY_COMMAND = "CHECK_READY"
const GET_POSITION_COMMAND = "GET_POSITION"
const SET_TARGET_COMMAND = "SET_TARGET"
const START_MOTOR_COMMAND = "START_MOTOR"
const STOP_MOTOR_COMMAND = "STOP_MOTOR"

function wait_until_ready(arduino)
    ready = false
    response = ""

    while !ready
        try
            println("Checking if the Arduino is ready...")

            # Set the read and write timeouts
            set_read_timeout(arduino, 1)  # 1 second
            set_write_timeout(arduino, 1)  # 1 second

            # Send the CHECK_READY command to the Arduino
            write(arduino, "$CHECK_READY_COMMAND\n")

            # Wait for the response
            response = readline(arduino)
        catch e
            if isa(e, LibSerialPort.Timeout)
                println("Arduino is not ready. Retrying...")
            else
                rethrow(e)
            end
        else
            # Check if the Arduino is ready
            ready = chomp(response) == "READY"
        end
    end

    println("Arduino is ready to receive commands.")
end

function gamepad_control()
    # Initialize motor variables
    actual_position_motor = 0
    target_position_motor = 0

    # Initialize the joystick
    js = open_joystick()
    jsaxes = JSState()
    jsbuttons = JSButtonState()
    async_read!(js, jsaxes, jsbuttons)

    # Joystick to motor velocity multiplier
    multiplier = 50.0

    LibSerialPort.open("/dev/cu.usbserial-110", BAUD_RATE) do arduino
        # Wait until the Arduino is ready
        wait_until_ready(arduino)

        # Initialize variables for tracking time
        last_update_time = now()

        # Main loop
        running = true
        while running
            # Set the read and write timeouts
            set_read_timeout(arduino, 0.1)
            set_write_timeout(arduino, 0.1)

            # Get the current time
            current_time = now()

            # Calculate the elapsed time since the last update
            elapsed_time = current_time - last_update_time

            if elapsed_time >= Millisecond(1000 / CONTROL_FREQUENCY)
                # Get the actual position from the Arduino
                write(arduino, "$GET_POSITION_COMMAND\n")
                actual_position_motor = parse(Int, chomp(readline(arduino)))

                # Calculate the motor velocity based on the joystick input
                velocity = round(Int, jsaxes.x * multiplier)

                # Calculate the target position
                target_position_motor = actual_position_motor + velocity

                # Send the target position to the Arduino
                write(arduino, "$SET_TARGET_COMMAND $target_position_motor\n")

                # Update the last update time
                last_update_time = current_time

                # Print the actual and target positions
                print("Actual position: $actual_position_motor, ")
                println("Target position: $target_position_motor")
            end

            if jsbuttons.btn1.val  # Xbox A-button
                # Start the motor
                write(arduino, "$START_MOTOR_COMMAND\n")
            elseif jsbuttons.btn2.val  # Xbox B-button
                # Stop the motor
                write(arduino, "$STOP_MOTOR_COMMAND\n")
            elseif jsbuttons.btn5.val  # Xbox Y-button
                # Stop the motor
                write(arduino, "$STOP_MOTOR_COMMAND\n")

                # Stop the main loop
                running = false
            end

            # Sleep for a short period of time
            sleep(Millisecond(10))  # 10 ms
        end
    end
end

export
    check_ready,
    gamepad_control

end # module RotaryInvertedPendulum
