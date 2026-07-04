function se = get_spectral_efficiency_from_sinr(sinr_db)
% GET_SPECTRAL_EFFICIENCY_FROM_SINR Maps SINR (dB) to spectral efficiency (bps/Hz).

    se = zeros(size(sinr_db));
    se(sinr_db >= -5.0 & sinr_db < -2.5) = 0.25; % QPSK ~1/8
    se(sinr_db >= -2.5 & sinr_db < 0.0)  = 0.5;  % QPSK ~1/4
    se(sinr_db >= 0.0  & sinr_db < 2.5)  = 1.0;  % QPSK ~1/2
    se(sinr_db >= 2.5  & sinr_db < 5.5)  = 2.0;  % 16-QAM ~1/2
    se(sinr_db >= 5.5  & sinr_db < 9.0)  = 3.0;  % 16-QAM ~3/4
    se(sinr_db >= 9.0  & sinr_db < 13.0) = 4.0;  % 64-QAM ~2/3
    se(sinr_db >= 13.0 & sinr_db < 16.5) = 5.0;  % 64-QAM ~5/6
    se(sinr_db >= 16.5) = 6.6;  % 256-QAM ~5/6
end