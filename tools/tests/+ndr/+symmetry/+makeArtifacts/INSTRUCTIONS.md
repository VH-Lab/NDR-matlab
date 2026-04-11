# NDR Symmetry Artifacts Instructions

This folder contains MATLAB unit tests whose purpose is to generate standard NDR artifacts for symmetry testing with other NDR language ports (e.g., Python).

## Rules for `makeArtifacts` tests:

1. **Artifact Location**: Tests must store their generated artifacts in the system's temporary directory (`tempdir`).
2. **Directory Structure**: Inside the temporary directory, artifacts must be placed in a specific nested folder structure:
   `NDR/symmetryTest/matlabArtifacts/<namespace>/<class_name>/<test_name>/`

   - `<namespace>`: The last part of the MATLAB package namespace. For example, for a test located at `tools/tests/+ndr/+symmetry/+makeArtifacts/+reader`, the namespace is `reader`.
   - `<class_name>`: The name of the test class (e.g., `readData`).
   - `<test_name>`: The specific name of the test method being executed (e.g., `testReadDataArtifacts`).

3. **Persistent Teardown**: The generated artifact files **MUST** persist in the temporary directory so that the Python test suite can read them. Do NOT delete the artifact directory in a test teardown method.

4. **Artifact Contents**: Every `makeArtifacts` test should produce at minimum:
   - A `metadata.json` file describing the channels, sample rates, `t0`/`t1` boundaries,
     and epoch clock types returned by the reader.
   - A `readData.json` file containing a small, reproducible sample of data read via
     `readchannels_epochsamples(...)` (or the equivalent reader call) so the Python suite
     can verify numerical parity.

5. **Deterministic Input**: Tests should read from the checked-in `example_data/` files
   in the NDR-matlab repository so that both language ports operate on byte-identical inputs.

## Example:
For a test class `readData.m` in `tools/tests/+ndr/+symmetry/+makeArtifacts/+reader` with a test method `testReadDataArtifacts`, the artifacts should be saved to:
`[tempdir(), 'NDR/symmetryTest/matlabArtifacts/reader/readData/testReadDataArtifacts/']`

## Running

From MATLAB:

```matlab
% Generate artifacts
results = runtests('ndr.symmetry.makeArtifacts', 'IncludeSubpackages', true);
```
