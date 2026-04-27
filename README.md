# A-Simulation-Vision-for-Achieving-Digital-Transformation-in-Tripoli-From-5G-to-6G
Overview

This repository contains the complete MATLAB simulation codebase developed for my M.Sc. thesis, "A Simulation Vision for Achieving Digital Transformation in Tripoli: From 5G to 6G." It provides a robust, system-level framework for modeling advanced telecommunications networks within a dense urban topology (Tripoli, Libya).

Additionally, this repository hosts the extended simulation code for a research paper currently under submission to IEEE GLOBECOM 2026, which introduces novel fairness algorithms for 6G networks.

Repository Structure & Modules
1. M.Sc. Thesis Simulation (Core Codebase)

The primary thesis codebase is divided into two major evolutionary phases of urban network architecture:

Phase 1: 5G HetNet Optimization: Focuses on maximizing performance, capacity, and load balancing of 5G Heterogeneous Networks (Macro + Small Cells) operating within Tripoli's dense, real-world urban grid.

Phase 2: The 6G RIS Transition: Models the leap to 6G by introducing Reconfigurable Intelligent Surfaces (RIS). This module simulates 60 GHz (V-Band) sub-Terahertz propagation and demonstrates how RIS deployments can be utilized to overcome severe Non-Line-of-Sight (NLOS) urban blockages.

2. IEEE GLOBECOM 2026 Extension

File: GlobeCom_2026.m 

This module contains the specific, physically-constrained simulation logic used to generate the results for the paper titled:

"Optimizing 6G RIS Deployments in Dense Urban Topologies: Mitigating Fairness Trade-offs via Multi-RIS Collaborative Beamforming."

Key Innovation: This file introduces a novel concept not covered in the original thesis: Multi-RIS Collaborative Beamforming (MCB).

It implements a CQI-driven, log-scaled Proportional Fair (PF) scheduling heuristic.

It successfully transcends traditional 6G capacity-fairness trade-offs by intelligently distributing RIS array elements, achieving near-optimal Proportional Fair utility (>98%) in a fraction of a millisecond.

Key Features

Geographic Topologies: Integrates realistic spatial configurations modeled after the city center of Tripoli.

3GPP TR 38.901 Compliance: Enforces strict physical constraints, including realistic sub-Terahertz pathloss, blockages, phase quantization losses, and spectral efficiency hardware caps.

Algorithmic Validation: Includes a toy model demonstrating the optimality gap and computational efficiency of the proposed MCB heuristic against exhaustive global search methods.

Citation & Usage

If you utilize this code for your own research, please cite the associated M.Sc. thesis and/or the GLOBECOM 2026 paper once published.
