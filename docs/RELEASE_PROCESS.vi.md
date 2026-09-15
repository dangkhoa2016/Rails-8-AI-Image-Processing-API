# Lộ trình release

## Mốc phiên bản hiện tại

`v1.0.0` là phiên bản duy nhất của project. Đây là một mốc release local có thể di chuyển:
sau khi validation bắt buộc thành công trên một commit `main` sạch
mới hơn, `script/refresh_v1_0_0_tag.sh` sẽ thay thế local annotated tag.

Quy trình này không tạo remote tag, GitHub Release, image publication hoặc
deployment. Xác định chính xác target hiện tại bằng:

```sh
git rev-parse v1.0.0^{commit}
```

## Quy tắc release

- Chạy validation đã được tài liệu hóa trước khi làm mới marker và ghi nhận kết
  quả quan sát được trong acceptance record.
- Chỉ làm mới local `v1.0.0` từ checkout `main` sạch bằng
  `script/refresh_v1_0_0_tag.sh`; tag này được chủ đích cho phép di chuyển sau
  một validation thành công khác. Corrective descendant đã được validation có
  thể dùng mode tường minh `RELEASE_ALLOW_VALIDATED_DESCENDANT=1`, và có thể
  chọn ancestor qua `RELEASE_BASE_REF` (mặc định là `main`). Ngoại lệ này vẫn
  bắt buộc worktree sạch và acceptance evidence; branch tùy ý hoặc candidate
  không là descendant của base đều bị từ chối.
- Giữ `CHANGELOG.md` là lịch sử release của project. Các tài liệu upstream
  trong `docs/history/` chỉ phục vụ attribution.
- Không suy diễn remote release, registry image, deployment, AI qualification
  hoặc production-traffic qualification từ local marker này.

Xem [acceptance record v1.0.0](releases/v1.0.0-acceptance.md) để biết phạm vi,
bằng chứng và các nội dung không phải bằng chứng.
