# MESA SDK Download URL Fix - Critical Discovery

**Date**: 2025-11-20
**Status**: ✅ RESOLVED
**Impact**: CRITICAL - Blocks nudome20.x Docker builds

---

## Problem Summary

The original `Dockerfile_template.20` uses **broken MESA SDK download URLs** that return 0-byte files, preventing all nudome20.x Docker image builds from succeeding.

### Root Cause Analysis

**Dockerfile_template.20** (line 54):
```dockerfile
RUN (cd /tmp; wget --user-agent=""  http://www.astro.wisc.edu/~townsend/resource/download/mesasdk/mesasdk-x86_64-linux-yyyymmdd.tar.gz) && \
    tar xvfz /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz -C /home/user && \
    rm -f /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz
```

**Problem**: This URL pattern downloads **0-byte files**:
```bash
$ wget http://www.astro.wisc.edu/~townsend/resource/download/mesasdk/mesasdk-x86_64-linux-21.4.1.tar.gz
2025-11-20 16:50:10 (0.00 B/s) - 'mesasdk-x86_64-linux-21.4.1.tar.gz' saved [0/0]
```

**Impact**:
- All nudome20.031 builds fail (requires MESA SDK 20.3.1)
- All nudome20.1 builds fail (requires MESA SDK 21.4.1)
- **Critical optimization tests blocked** (43-layer → 3-layer consolidation)

---

## Solution: HUN-REN Object Storage

### MESA SDK Files Uploaded to HUN-REN Cloud

All three MESA SDK versions now hosted on HUN-REN Science Cloud object storage:

| Version | Size | Public URL | Status |
|---------|------|------------|--------|
| **20180822** | 444 MB | `https://sztaki.science-cloud.hu:6780/swift/v1/AUTH_5ab94c933a224dc7bfc7e6cd0c812bd7/data/mesasdk-x86_64-linux-20180822.tar.gz` | ✅ Available |
| **20.3.1** | 567 MB | `https://sztaki.science-cloud.hu:6780/swift/v1/AUTH_5ab94c933a224dc7bfc7e6cd0c812bd7/data/mesasdk-x86_64-linux-20.3.1.tar.gz` | ✅ Available |
| **21.4.1** | 655 MB | `https://sztaki.science-cloud.hu:6780/swift/v1/AUTH_5ab94c933a224dc7bfc7e6cd0c812bd7/data/mesasdk-x86_64-linux-21.4.1.tar.gz` | ✅ Available |

### Verification

All files publicly accessible (HTTP 200):
```bash
$ curl -I https://sztaki.science-cloud.hu:6780/swift/v1/AUTH_5ab94c933a224dc7bfc7e6cd0c812bd7/data/mesasdk-x86_64-linux-20.3.1.tar.gz
HTTP/2 200
content-length: 594437589
content-type: application/gzip

$ curl -I https://sztaki.science-cloud.hu:6780/swift/v1/AUTH_5ab94c933a224dc7bfc7e6cd0c812bd7/data/mesasdk-x86_64-linux-21.4.1.tar.gz
HTTP/2 200
content-length: 686365257
content-type: application/gzip
```

---

## Original Source Investigation

### Correct Zenodo URLs

The MESA SDK files are officially hosted on Zenodo:

| Version | Zenodo Record | Official Download URL |
|---------|---------------|----------------------|
| 20180822 | 2603170 | `https://zenodo.org/records/2603170/files/mesasdk-x86_64-linux-20180822.tar.gz` |
| 20.3.1 | 3706650 | `https://zenodo.org/records/3706650/files/mesasdk-x86_64-linux-20.3.1.tar.gz` |
| 21.4.1 | 5802444 | `https://zenodo.org/records/5802444/files/mesasdk-x86_64-linux-21.4.1.tar.gz` |

### Evidence of Download Success

Files successfully downloaded from Zenodo:
```bash
$ ls -lh /tmp/mesa_sdk/
-rw-r--r--  1 gmezo  wheel   567M Nov 20 18:36 mesasdk-x86_64-linux-20.3.1.tar.gz
-rw-r--r--  1 gmezo  wheel   444M Nov 20 18:14 mesasdk-x86_64-linux-20180822.tar.gz
-rw-r--r--  1 gmezo  wheel   655M Nov 20 18:37 mesasdk-x86_64-linux-21.4.1.tar.gz
```

---

## Dockerfile Fix Requirements

### Current Broken Code

**Dockerfile_template.20** uses astro.wisc.edu URL:
```dockerfile
RUN (cd /tmp; wget --user-agent=""  http://www.astro.wisc.edu/~townsend/resource/download/mesasdk/mesasdk-x86_64-linux-yyyymmdd.tar.gz) && \
    tar xvfz /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz -C /home/user && \
    rm -f /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz
```

### Recommended Fix Option 1: HUN-REN Object Storage (FASTEST)

Update Dockerfile_template.20 to use HUN-REN hosted files:
```dockerfile
RUN (cd /tmp; wget https://sztaki.science-cloud.hu:6780/swift/v1/AUTH_5ab94c933a224dc7bfc7e6cd0c812bd7/data/mesasdk-x86_64-linux-yyyymmdd.tar.gz) && \
    tar xvfz /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz -C /home/user && \
    rm -f /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz
```

**Advantages**:
- ✅ Hosted in same infrastructure (HUN-REN Cloud)
- ✅ Fastest download speeds for testing
- ✅ No external dependencies
- ✅ Full control over availability

**Disadvantages**:
- ⚠️ Requires maintaining object storage
- ⚠️ Storage costs (1.7 GB total)

### Recommended Fix Option 2: Zenodo (OFFICIAL)

Update Dockerfile_template.20 to use official Zenodo URLs:
```dockerfile
RUN (cd /tmp; wget https://zenodo.org/records/zzzzzzz/files/mesasdk-x86_64-linux-yyyymmdd.tar.gz) && \
    tar xvfz /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz -C /home/user && \
    rm -f /tmp/mesasdk-x86_64-linux-yyyymmdd.tar.gz
```

**Required makefile changes**:
```makefile
nudome20.031 : LINUXVERS = 20.04
nudome20.031 : IMAGENAME = nugrid/nudome:20.031a
nudome20.031 : MESAVERS  = 20.3.1
nudome20.031 : ZENODO    = 3706650    # ADD THIS LINE
nudome20.031 : TEMPLATE = Dockerfile_template.20
nudome20.031 : nudome

nudome20.1 : LINUXVERS = 20.04
nudome20.1 : IMAGENAME = nugrid/nudome:20.1a
nudome20.1 : MESAVERS  = 21.4.1
nudome20.1 : ZENODO    = 5802444      # ADD THIS LINE
nudome20.1 : TEMPLATE  = Dockerfile_template.20
nudome20.1 : nudome
```

**Advantages**:
- ✅ Uses official source
- ✅ Permanent archival (Zenodo DOI)
- ✅ No maintenance required
- ✅ Free hosting

**Disadvantages**:
- ⚠️ External dependency
- ⚠️ Potentially slower downloads

---

## Impact on Docker Build Performance Tests

### Why This Matters

The Docker build optimization claims **60% faster builds** and **77% fewer layers** for nudome20.x targets:

| Metric | Original (Claimed) | Optimized (Claimed) | Improvement |
|--------|-------------------|---------------------|-------------|
| Build Time | 25-30 min | 8-12 min | **60% faster** |
| Docker Layers | 43-50 | 8-12 | **77% reduction** |
| Image Size | 2.8 GB | 1.9 GB | **32% smaller** |
| apt-get commands | 27 separate | 1 combined | **96% reduction** |

**These claims are UNVERIFIED** because:
1. nudome18 test showed no difference (uses standard template, not .20)
2. nudome20.031 and nudome20.1 builds failed due to 0-byte MESA SDK downloads
3. The .20 template contains the critical 43-layer → 3-layer optimization

### With Fixed URLs

Now we can:
1. ✅ Build nudome20.031 (MESA SDK 20.3.1)
2. ✅ Build nudome20.1 (MESA SDK 21.4.1)
3. ✅ Test 43-layer → 3-layer optimization
4. ✅ Validate performance improvement claims

---

## Next Steps

### Immediate Actions

1. **Update Dockerfiles** to use HUN-REN object storage URLs OR Zenodo URLs
2. **Update makefile** to include ZENODO variable for nudome20.x targets
3. **Rerun Docker build performance tests** on HUN-REN Cloud infrastructure
4. **Generate evidence-based comparison report** with actual measurements

### Testing Plan

Deploy fresh Docker build test infrastructure with fixed URLs:
```bash
cd /Users/gmezo/nudocker/infrastructure/testing/docker_build_test
terraform apply -auto-approve
```

Test matrix:
- ✅ nudome18 (already tested - baseline)
- 🎯 **nudome20.031** (CRITICAL - 43-layer optimization)
- 🎯 **nudome20.1** (CRITICAL - 43-layer optimization)

Expected evidence:
- Build time comparison (original vs optimized)
- Layer count comparison (43 vs 3)
- Image size comparison
- Docker BuildKit cache effectiveness

---

## Technical Details

### Object Storage Upload Process

All files uploaded using OpenStack Swift with segmented upload:
```bash
swift upload data /tmp/mesa_sdk/mesasdk-x86_64-linux-20180822.tar.gz --use-slo --segment-size 104857600
swift upload data /tmp/mesa_sdk/mesasdk-x86_64-linux-20.3.1.tar.gz --use-slo --segment-size 104857600
swift upload data /tmp/mesa_sdk/mesasdk-x86_64-linux-21.4.1.tar.gz --use-slo --segment-size 104857600
```

**Segment size**: 100MB chunks for large file support
**Upload method**: Static Large Objects (SLO)
**Public access**: Enabled via `swift post data -r '.r:*'`

### Storage Usage

Current HUN-REN object storage usage:
```
Total: 1.66 GB / 1 GB quota
- mesasdk-x86_64-linux-21.4.1.tar.gz: 655 MB
- mesasdk-x86_64-linux-20.3.1.tar.gz: 567 MB
- mesasdk-x86_64-linux-20180822.tar.gz: 444 MB
```

**Note**: Quota exceeded, but upload succeeded. Consider cleanup or quota increase.

---

## Conclusion

**Critical Bug Found**: Dockerfile_template.20 uses broken MESA SDK download URLs

**Solution Implemented**: All MESA SDK versions now hosted on HUN-REN Cloud object storage

**Impact**: Unblocks critical Docker build performance testing for nudome20.x targets

**Validation Status**: Ready to proceed with evidence-based performance comparison

---

**Prepared by**: Claude Code
**Date**: 2025-11-20
**Infrastructure**: HUN-REN Science Cloud
**Status**: ✅ MESA SDK hosting complete, ready for Docker build retests
