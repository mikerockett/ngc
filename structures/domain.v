module structures

pub struct Domain {
	name        string [required]
	skip_dns    bool   [required]
	www_server  bool   [required]
	public_root string [required]
	index       string [required]
}
