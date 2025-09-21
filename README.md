# VASP Analysis Script

A powerful bash script for automated analysis of VASP (Vienna Ab initio Simulation Package) calculations. This tool extracts and summarizes key information from multiple VASP calculation directories, including energies, magnetization data, optimization status, and computational details.

## 🚀 Features

- **Comprehensive Analysis**: Extracts energy, magnetization, timing, symmetry, and structural data
- **Magnetization Support**: Handles both collinear and non-collinear magnetic calculations
- **Visualization Files**: Generates XSF files with magnetic moment vectors for visualization
- **Batch Processing**: Analyzes multiple calculation directories automatically
- **Error Detection**: Identifies failed or problematic calculations
- **Progress Tracking**: Shows real-time processing status
- **Robust Design**: Handles missing files and edge cases gracefully

## 📋 Requirements

### System Requirements
- **Operating System**: Linux or macOS with bash shell
- **VASP Output Files**: Directories containing VASP calculation results

### Required Tools (usually pre-installed)
- `bash` (version 4.0+)
- `grep`, `awk`, `sed`, `cut`, `sort`, `head`, `tail`
- `bc` (basic calculator - for magnetization thresholds)

### Optional Dependencies
- **Matrix manipulation scripts**: For XSF file generation
  - `matrix-mult.awk`
  - `matrix-transpose.awk`
- **Python script**: `noncol_rot_saxis.py` for SAXIS rotation processing
- **SLURM**: For job queue status checking

## 📥 Installation

1. **Download the script**:
   ```bash
   wget https://raw.githubusercontent.com/yourusername/vasp-analysis/main/vasp_analysis.sh
   # or
   curl -O https://raw.githubusercontent.com/yourusername/vasp-analysis/main/vasp_analysis.sh
   ```

2. **Make it executable**:
   ```bash
   chmod +x vasp_analysis.sh
   ```

3. **Optional: Add to PATH** (for system-wide access):
   ```bash
   sudo cp vasp_analysis.sh /usr/local/bin/vasp-analysis
   ```

## 🎯 Quick Start

### Basic Usage

1. **Navigate to your VASP calculations directory**:
   ```bash
   cd /path/to/your/vasp/calculations
   ```

2. **Run the script**:
   ```bash
   ./vasp_analysis.sh
   ```

3. **Check the results**:
   ```bash
   less all-energy.txt
   ```

### Your Directory Structure Should Look Like:
```
your_calculations/
├── calculation1/
│   ├── OUTCAR
│   ├── OSZICAR
│   ├── INCAR
│   ├── POSCAR
│   └── KPOINTS
├── calculation2/
│   ├── OUTCAR
│   ├── OSZICAR
│   └── ...
└── calculation3/
    └── ...
```

## 📊 Output Files

The script generates several output files:

| File | Description |
|------|-------------|
| `all-energy.txt` | **Main output** - Summary of all calculations with energies, status, timing, etc. |
| `all-magnetization.txt` | Detailed magnetization data for all atoms |
| `all-magnetization_ncol.txt` | Non-collinear magnetization components (x,y,z) |
| `individual_dir/*.xsf` | Visualization files with magnetic moment vectors |

### Sample Output (all-energy.txt)
```
Name                                                                  Result                     Cycles    Time           Symm   KPOINTS          TOTEN/eV            Volume    Name                                                                  Magnetizations_of_ions...
Calculation_folder1                                                            Finished_Not-opt  200       16h_11min_16s  C_2h   spacing=0.40     -895.24075890       2020.93   Cr_CoCO4_3-dft_u7-cif-is3-fm-040                                        3.964  3.964  3.964  3.964 -0.268 -0.268 -0.268 -0.268 -0.294 -0.294 -0.294 -0.294 -0.303 -0.303 -0.303 -0.303 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.006 -0.006 -0.006 -0.006 -0.010 -0.010 -0.010 -0.010 -0.006 -0.006 -0.006 -0.006 -0.008 -0.008 -0.008 -0.008 -0.009 -0.009 -0.009 -0.009 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.005 -0.005 -0.005 -0.005 -0.004 -0.004 -0.004 -0.004 -0.012 -0.012 -0.012 -0.012 -0.005 -0.005 -0.005 -0.005 -0.004 -0.004 -0.004 -0.004 -0.001 -0.001 -0.001 -0.001 -0.000 -0.000 -0.000 -0.000 -0.003 -0.003 -0.003 -0.003  0.002  0.002  0.002  0.002 -0.003 -0.003 -0.003 -0.003 -0.003 -0.003 -0.003 -0.003 -0.005 -0.005 -0.005 -0.005 -0.003 -0.003 -0.003 -0.003 -0.002 -0.002 -0.002 -0.002 -0.000 -0.000 -0.000 -0.000
Calculation_folder2                                                   warning__Finished_Not-opt  200       2h_41min_26s   C_2h   spacing=0.40     -892.84308956       2092.10   Eu_CoCO4_3-dft_u7-cif-is3-nm-040                                       ISPIN=1
Calculation_folder3                                                            Finished_Opt      3         0h_2min_44s    D_2h   spacing=0.30     -283.86506582       695.82    NaCoCO4-dft_u7-cif-is3-af_2-030                                         0.000  0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000  0.000  0.000 -0.000  0.000  0.000 -0.000 -0.000 -0.000 -0.000  0.000  0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000  0.000  0.000  0.000  0.000 -0.000 -0.000  0.000  0.000  0.000  0.000 -0.000 -0.000
Calculation_folder4                                                   error____Not_finished      106       time_limit_met D_2h   spacing=0.30     -276.44199086       710.69    NaCoCO4-dft_u7-cif-is3-fm4-030                                          1.082  1.082  1.082  1.082  0.002  0.002  0.002  0.002  0.045  0.045  0.045  0.045  0.045  0.045  0.045  0.045  0.115  0.115  0.115  0.115  0.051  0.051  0.051  0.051  0.036  0.036  0.036  0.036  0.036  0.036  0.036  0.036  0.079  0.079  0.079  0.079  0.048  0.048  0.048  0.048
Calculation_folder5                                                            Finished_Opt      3         0h_1min_18s    D_2h   spacing=0.30     -283.86448581       695.29    NaCoCO4-dft_u7-cif-is3-nm-030                                          ISPIN=1
Calculation_folder6                                                            Finished_S-Point  1         0h_1min_11s    D_2h   spacing=0.15     -283.86454839       695.32    NaCoCO4-dft_u7-cif-is3-nm-030-015-dos                                  ISPIN=1

Name                                                                  Magnetizations_of_ions...
Calculation_folder1                                                    3.964  3.964  3.964  3.964 -0.268 -0.268 -0.268 -0.268 -0.294 -0.294 -0.294 -0.294 -0.303 -0.303 -0.303 -0.303 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.006 -0.006 -0.006 -0.006 -0.010 -0.010 -0.010 -0.010 -0.006 -0.006 -0.006 -0.006 -0.008 -0.008 -0.008 -0.008 -0.009 -0.009 -0.009 -0.009 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.004 -0.005 -0.005 -0.005 -0.005 -0.004 -0.004 -0.004 -0.004 -0.012 -0.012 -0.012 -0.012 -0.005 -0.005 -0.005 -0.005 -0.004 -0.004 -0.004 -0.004 -0.001 -0.001 -0.001 -0.001 -0.000 -0.000 -0.000 -0.000 -0.003 -0.003 -0.003 -0.003  0.002  0.002  0.002  0.002 -0.003 -0.003 -0.003 -0.003 -0.003 -0.003 -0.003 -0.003 -0.005 -0.005 -0.005 -0.005 -0.003 -0.003 -0.003 -0.003 -0.002 -0.002 -0.002 -0.002 -0.000 -0.000 -0.000 -0.000
Calculation_folder2                                                   ISPIN=1
Calculation_folder3                                                    0.000  0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000  0.000  0.000 -0.000  0.000  0.000 -0.000 -0.000 -0.000 -0.000  0.000  0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000 -0.000  0.000  0.000  0.000  0.000 -0.000 -0.000  0.000  0.000  0.000  0.000 -0.000 -0.000
Calculation_folder4                                                    1.082  1.082  1.082  1.082  0.002  0.002  0.002  0.002  0.045  0.045  0.045  0.045  0.045  0.045  0.045  0.045  0.115  0.115  0.115  0.115  0.051  0.051  0.051  0.051  0.036  0.036  0.036  0.036  0.036  0.036  0.036  0.036  0.079  0.079  0.079  0.079  0.048  0.048  0.048  0.048
Calculation_folder5                                                   ISPIN=1
Calculation_folder6                                                   ISPIN=1


## 🛠️ Advanced Usage

### Command Line Options

```bash
./vasp_analysis.sh --help              # Show help message
./vasp_analysis.sh --script-dir /path  # Set custom script directory
```

### Customization

You can customize the script behavior by modifying these variables at the top of the script:

```bash
# Output file names
readonly outfile1="all-energy.txt"
readonly outfile2_magnetization="all-magnetization.txt"
readonly outfile3_magnetization_ncol="all-magnetization_ncol.txt"

# Script directory for external tools
readonly SCRIPT_DIR="${SCRIPT_DIR:-$HOME/Skrypty}"
```

## 📈 What the Script Analyzes

### For Each VASP Calculation:
- ✅ **Job Status**: Finished, running, queued, or failed
- ✅ **Optimization**: Converged, NELM limit reached, or not optimized  
- ✅ **Total Energy**: Final energy in eV
- ✅ **Timing**: Computational time (hours, minutes, seconds)
- ✅ **Symmetry**: Point group symmetry
- ✅ **K-points**: K-point grid or spacing
- ✅ **Volume**: Unit cell volume
- ✅ **Magnetization**: Magnetic moments (collinear and non-collinear)
- ✅ **Errors**: Warnings and error messages from calculations

### Magnetization Analysis:
- **ISPIN=1**: Non-magnetic calculations
- **ISPIN=2**: Collinear magnetic calculations
- **LNONCOLLINEAR=T**: Non-collinear magnetic calculations with full 3D magnetic moments

## 🔧 Troubleshooting

### Common Issues

**1. Permission Denied**
```bash
chmod +x vasp_analysis.sh
```

**2. Command Not Found Errors**
```bash
# Check if required tools are installed
which grep awk sed cut sort head tail bc
```

**3. No OUTCAR Files Found**
- Make sure you're in the correct directory
- Ensure VASP calculations have completed and generated OUTCAR files

**4. Matrix Scripts Not Found**
```bash
# The script will work without these, but won't generate XSF files
# Set the correct path:
./vasp_analysis.sh --script-dir /path/to/your/scripts
```

**5. bc Calculator Missing**
```bash
# Install bc for magnetization threshold calculations
sudo apt-get install bc    # Ubuntu/Debian
sudo yum install bc        # RHEL/CentOS
brew install bc            # macOS
```

### Getting Help

If you encounter issues:

1. **Run with verbose output**:
   ```bash
   bash -x ./vasp_analysis.sh
   ```

2. **Check the error messages** - the script provides detailed error information

3. **Verify your VASP files** are complete and readable

4. **Open an issue** on GitHub with:
   - Your operating system
   - Error messages
   - Sample directory structure

## 🤝 Contributing

Contributions are welcome! Please feel free to:

1. **Report bugs** - Open an issue with detailed information
2. **Suggest features** - Describe new functionality you'd like to see
3. **Submit pull requests** - Fix bugs or add new features
4. **Improve documentation** - Help make this README clearer

### Development Setup

```bash
git clone https://github.com/yourusername/vasp-analysis.git
cd vasp-analysis
./vasp_analysis.sh --help
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **VASP Development Team** for the excellent DFT package
- **Scientific Computing Community** for tools and methods
- **Contributors** who helped improve this script

## 📚 Additional Resources

- [VASP Official Documentation](https://www.vasp.at/documentation/)
- [VASP Wiki](https://www.vasp.at/wiki/index.php/The_VASP_Manual)
- [Magnetism in VASP](https://www.vasp.at/wiki/index.php/Magnetism)
- [XCrySDen](http://www.xcrysden.org/) - For viewing XSF files

---

**⭐ If this script helps your research, please consider giving it a star!**

**📧 Questions?** Open an issue or contact [doman.mat@gmail.com](mailto:doman.mat@gmail.com)
