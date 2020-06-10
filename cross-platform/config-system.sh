#!/usr/bin/env bash
echo '
APT::Install-Recommends "1";
APT::NeverAutoRemove:: ".*";

Acquire::Check-Valid-Until "0";
APT::Get::Assume-Yes "true";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "1";
Acquire::AllowDowngradeToInsecureRepositories "1";

Acquire::CompressionTypes::Order { "gz"; };
APT::Compressor::gzip::CompressArg:: "-1";
APT::Compressor::xz::CompressArg:: "-1";
APT::Compressor::bzip2::CompressArg:: "-1";
APT::Compressor::lzma::CompressArg:: "-1";
' | sudo tee /etc/apt/apt.conf.d/99Z_Custom

# sudo apt-get purge man-db -y