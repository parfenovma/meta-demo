module ReferenceDemo

using DelimitedFiles
using LinearAlgebra

export ReferenceExperiment,
       gain_summary,
       load_reference_experiment,
       validate_reference_experiment

Base.@kwdef struct ReferenceExperiment
    y_mm::Vector{Float64}
    sinusoidal_nm::Vector{Float64}
    straight_nm::Vector{Float64}
    frequency_khz::Float64
    source_traction_mpa::Float64
    defect_radius_mm::Float64
    focus_x_mm::Float64
    receiver_x_mm::Float64
    reported_sinusoidal_rms_nm::Float64
    reported_straight_rms_nm::Float64
    reported_local_energy_gain::Float64
    reported_scattering_gain::Float64
    reported_snr_improvement_db::Float64
end

function _column(name, data, columns)
    index = only(findall(==(name), columns))
    Float64.(data[:, index])
end

function _summary_value(name, data, columns)
    index = only(findall(==(name), columns))
    Float64(data[1, index])
end

function load_reference_experiment(data_directory=joinpath(@__DIR__, "..", "data"))
    profile_data, profile_header = readdlm(
        joinpath(data_directory, "receiver_scattered_profiles.csv"),
        ',',
        header=true,
    )
    summary_data, summary_header = readdlm(
        joinpath(data_directory, "material_lens_defect_summary.csv"),
        ',',
        header=true,
    )
    profile_columns = vec(String.(profile_header))
    summary_columns = vec(String.(summary_header))

    experiment = ReferenceExperiment(
        y_mm=_column("y_mm", profile_data, profile_columns),
        sinusoidal_nm=1e9 .* _column("selected_scattered_ux_m", profile_data, profile_columns),
        straight_nm=1e9 .* _column("uniform_scattered_ux_m", profile_data, profile_columns),
        frequency_khz=_summary_value("frequency_hz", summary_data, summary_columns) / 1e3,
        source_traction_mpa=_summary_value("source_traction_pa", summary_data, summary_columns) / 1e6,
        defect_radius_mm=_summary_value("defect_radius_mm", summary_data, summary_columns),
        focus_x_mm=_summary_value("focus_x_mm", summary_data, summary_columns),
        receiver_x_mm=_summary_value("receiver_x_mm", summary_data, summary_columns),
        reported_sinusoidal_rms_nm=1e9 * _summary_value("selected_receiver_scattered_ux_rms_m", summary_data, summary_columns),
        reported_straight_rms_nm=1e9 * _summary_value("uniform_receiver_scattered_ux_rms_m", summary_data, summary_columns),
        reported_local_energy_gain=_summary_value("local_energy_gain", summary_data, summary_columns),
        reported_scattering_gain=_summary_value("scattering_gain_equal_noise_snr_gain", summary_data, summary_columns),
        reported_snr_improvement_db=_summary_value("snr_improvement_db", summary_data, summary_columns),
    )
    validate_reference_experiment(experiment)
    return experiment
end

function gain_summary(experiment::ReferenceExperiment)
    sinusoidal_rms_nm = norm(experiment.sinusoidal_nm) / sqrt(length(experiment.sinusoidal_nm))
    straight_rms_nm = norm(experiment.straight_nm) / sqrt(length(experiment.straight_nm))
    scattering_gain = sinusoidal_rms_nm / straight_rms_nm
    return (
        sinusoidal_rms_nm=sinusoidal_rms_nm,
        straight_rms_nm=straight_rms_nm,
        scattering_gain=scattering_gain,
        snr_improvement_db=20 * log10(scattering_gain),
        local_energy_gain=experiment.reported_local_energy_gain,
    )
end

function validate_reference_experiment(experiment::ReferenceExperiment)
    count = length(experiment.y_mm)
    count > 1 || throw(ArgumentError("receiver profile must contain at least two samples"))
    length(experiment.sinusoidal_nm) == count || throw(ArgumentError("sinusoidal profile length mismatch"))
    length(experiment.straight_nm) == count || throw(ArgumentError("straight profile length mismatch"))
    issorted(experiment.y_mm) || throw(ArgumentError("receiver coordinates must be sorted"))
    all(isfinite, experiment.sinusoidal_nm) || throw(ArgumentError("sinusoidal profile must be finite"))
    all(isfinite, experiment.straight_nm) || throw(ArgumentError("straight profile must be finite"))

    calculated = gain_summary(experiment)
    isapprox(calculated.sinusoidal_rms_nm, experiment.reported_sinusoidal_rms_nm; rtol=1e-12) ||
        throw(ArgumentError("sinusoidal RMS does not match summary"))
    isapprox(calculated.straight_rms_nm, experiment.reported_straight_rms_nm; rtol=1e-12) ||
        throw(ArgumentError("straight RMS does not match summary"))
    isapprox(calculated.scattering_gain, experiment.reported_scattering_gain; rtol=1e-12) ||
        throw(ArgumentError("scattering gain does not match summary"))
    isapprox(calculated.snr_improvement_db, experiment.reported_snr_improvement_db; rtol=1e-12) ||
        throw(ArgumentError("SNR improvement does not match summary"))
    return true
end

end
