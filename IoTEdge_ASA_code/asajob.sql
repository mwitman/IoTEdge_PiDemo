WITH TelemetryData AS 
(
-- Raspberry Pi data
SELECT
     CAST(machine.temperature AS float) as MachineTemp,
     CAST(machine.pressure AS float) as MachinePres,
     CAST(ambient.temperature AS float) as AmbientTemp,
     CAST(ambient.humidity AS float) as AmbientHum,
     CAST(timeCreated AS datetime) as eventTime
FROM hubinput
),
AnomalyDetectionSpike AS
(
    SELECT
        'MachineTemp-AnomalySpike' AS type,
        eventTime,
        CAST(MachineTemp AS float) AS temp,
        AnomalyDetection_SpikeAndDip(CAST(MachineTemp AS float), 95, 120, 'spikesanddips')
            OVER(LIMIT DURATION(second, 120)) AS SpikeAndDipScores
    FROM TelemetryData
),
AnomalyDetectionTrend AS
(
    SELECT
        'MachineTemp-AnomalyTrend' AS type,
        eventTime,
        CAST(MachineTemp AS float) AS temp,
        AnomalyDetection_ChangePoint(CAST(MachineTemp AS float), 80, 300) 
        OVER(LIMIT DURATION(second, 300)) AS ChangePointScores
    FROM TelemetryData
)

--output Anomaly Detection Spikes
SELECT
    type,
    eventTime,
    temp,
    CAST(GetRecordPropertyValue(SpikeAndDipScores, 'Score') AS float) AS
    SpikeAndDipScore,
    CAST(GetRecordPropertyValue(SpikeAndDipScores, 'IsAnomaly') AS bigint) AS
    IsSpikeAndDipAnomaly
INTO spikeoutput
FROM AnomalyDetectionSpike
WHERE GetRecordPropertyValue(SpikeAndDipScores, 'IsAnomaly') IS NOT NULL

--output Anomaly Detection Trends
SELECT
    type,
    eventTime,
    temp,
    CAST(GetRecordPropertyValue(ChangePointScores, 'Score') AS float) AS ChangePointScore,
    CAST(GetRecordPropertyValue(ChangePointScores, 'IsAnomaly') AS bigint) AS IsChangePointAnomaly
INTO trendoutput
FROM AnomalyDetectionTrend
WHERE GetRecordPropertyValue(ChangePointScores, 'IsAnomaly') IS NOT NULL

-- Aggregate Data; avg in each 10 seconds
SELECT
    'avgs-10sec' AS type,
    Min(eventTime),
    Avg(MachineTemp) AS avgmachinetemp,
    Avg(MachinePres) as avgmachinepres,
    Avg(AmbientTemp) as AmbientTemp,
    Avg(AmbientHum) as AmbientHum
INTO avghuboutput
FROM
    TelemetryData 
GROUP BY 
    'avgs', TumblingWindow(second, 10)

-- Raw Output
SELECT
    'RawOutput' AS type,
    *
INTO huboutput
FROM TelemetryData