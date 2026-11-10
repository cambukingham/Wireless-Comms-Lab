"""Channel map for the bench P9484M-AWT (four AWG outputs, two ADC inputs)."""

AWG_CHANNELS = (1, 2, 3, 4)
ADC_CHANNELS = (1, 2)


def validate_awg_channel(channel):
    if type(channel) is not int or channel not in AWG_CHANNELS:
        raise ValueError("Choose an AWG output channel from 1 to 4.")
    return channel


def select_awg_channel(instrument, channel):
    validate_awg_channel(channel)
    instrument.command(f":INST:CHAN {channel}")
    instrument.check_error()
    if int(instrument.query(":INST:CHAN?")) != channel:
        raise RuntimeError(f"Proteus did not confirm AWG CH{channel} selection.")


def playback_segment(channel, *, iq=False):
    """Reserve distinct segments because adjacent outputs share waveform memory."""
    return (129 if iq else 1) + validate_awg_channel(channel) - 1
