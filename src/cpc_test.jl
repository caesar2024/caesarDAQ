function get_config(CPCType)
    if (CPCType == :TSI3022) || (CPCType == :TSI3025)
        q = 0.3
        baud = 9600
        dbits = 7
        parity = SP_PARITY_EVEN
        sbits = 1
    elseif (CPCType == :TSI3771) || (CPCType == :TSI3772) || (CPCType == :TSI3776C)
        q = 1.0
        baud = 115200
        dbits = 8
        parity = SP_PARITY_NONE
        sbits = 1
    elseif (CPCType == :DMTCCN)
        q = 0.5
        baud = 9600
        dbits = 8
        parity = SP_PARITY_NONE
        sbits = 1
    elseif (CPCType == :MAGIC)
        q = 0.3
        baud = 115200
        dbits = 8
        parity = SP_PARITY_NONE
        sbits = 1
    end

    return (q = q, baud = baud, dbits = dbits, parity = parity, sbits = sbits)
end

function config(CPCType::Symbol, portname::String)
    conf = get_config(CPCType)

    port = LibSerialPort.sp_get_port_by_name(portname)
    LibSerialPort.sp_open(port, SP_MODE_READ_WRITE)
    config = LibSerialPort.sp_get_config(port)
    LibSerialPort.sp_set_config_baudrate(config, conf.baud)
    LibSerialPort.sp_set_config_parity(config, conf.parity)
    LibSerialPort.sp_set_config_bits(config, conf.dbits)
    LibSerialPort.sp_set_config_stopbits(config, conf.sbits)
    LibSerialPort.sp_set_config_rts(config, SP_RTS_OFF)
    LibSerialPort.sp_set_config_cts(config, SP_CTS_IGNORE)
    LibSerialPort.sp_set_config_dtr(config, SP_DTR_OFF)
    LibSerialPort.sp_set_config_dsr(config, SP_DSR_IGNORE)

    LibSerialPort.sp_set_config(port, config)

    return port
end

port1 = config(:MAGIC, "/dev/ttyS1")
port2 = config(:MAGIC, "/dev/ttyS2")
port3 = config(:MAGIC, "/dev/ttyS3")



